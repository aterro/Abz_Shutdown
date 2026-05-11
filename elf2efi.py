#!/usr/bin/env python3
"""Convert an ELF .so (from GNU-EFI build) to a PE/COFF EFI file.

Usage: python elf2efi.py input.so output.efi
"""

import sys
import lief

CHAR = lief.PE.Section.CHARACTERISTICS
F = lief.ELF.Section.FLAGS
RTYPE = lief.ELF.Relocation.TYPE

HCHAR = lief.PE.Header.CHARACTERISTICS
MACH = lief.PE.Header.MACHINE_TYPES
SUBSYS = lief.PE.OptionalHeader.SUBSYSTEM
BASE_TYPES = lief.PE.RelocationEntry.BASE_TYPES
DD_TYPES = lief.PE.DataDirectory.TYPES

PE_IMAGE_BASE = 0x10000000


def align_up(val, align):
    return (val + align - 1) & ~(align - 1)


def build_reloc_section(elf_binary, pe_factory):
    """Build PE .reloc section from ELF relocations and add via factory."""
    reloc_entries = []

    for reloc in elf_binary.relocations:
        if reloc.type in (RTYPE.AARCH64_RELATIVE, RTYPE.AARCH64_ABS64):
            reloc_entries.append(reloc.address)

    if not reloc_entries:
        return None

    reloc_entries.sort()

    blocks = []
    i = 0
    while i < len(reloc_entries):
        page_start = reloc_entries[i] & ~0xFFF
        block_entries = []
        while i < len(reloc_entries) and (reloc_entries[i] & ~0xFFF) == page_start:
            entry_val = (BASE_TYPES.DIR64.value << 12) | (reloc_entries[i] & 0xFFF)
            block_entries.append(entry_val)
            i += 1
        block_size = align_up(8 + len(block_entries) * 2, 4)
        while len(block_entries) * 2 + 8 < block_size:
            block_entries.append(0x0000)
            block_size = align_up(8 + len(block_entries) * 2, 4)
        blocks.append((page_start, block_size, block_entries))

    reloc_data = bytearray()
    for page_start, block_size, entries in blocks:
        reloc_data.extend(page_start.to_bytes(4, 'little'))
        reloc_data.extend(block_size.to_bytes(4, 'little'))
        for e in entries:
            reloc_data.extend(e.to_bytes(2, 'little'))
        while len(reloc_data) % 4 != 0:
            reloc_data.extend(b'\x00\x00')

    reloc_sec = lief.PE.Section('.reloc', list(reloc_data))
    reloc_sec.characteristics = (
        CHAR.CNT_INITIALIZED_DATA | CHAR.MEM_DISCARDABLE | CHAR.MEM_READ
    )
    pe_factory.add_section(reloc_sec)
    return len(reloc_data)


def copy_sections(elf_binary, pe_factory, keep_names):
    """Copy selected ELF sections to PE."""
    for elf_sec in elf_binary.sections:
        name = elf_sec.name
        if name not in keep_names:
            continue
        content = elf_sec.content
        if not content or len(content) == 0:
            continue

        flags = CHAR.MEM_READ
        if elf_sec.has(F.EXECINSTR):
            flags |= CHAR.CNT_CODE | CHAR.MEM_EXECUTE
        if elf_sec.has(F.WRITE):
            flags |= CHAR.CNT_INITIALIZED_DATA | CHAR.MEM_WRITE
        if not elf_sec.has(F.WRITE) and not elf_sec.has(F.EXECINSTR):
            flags |= CHAR.CNT_INITIALIZED_DATA

        pe_sec = lief.PE.Section(name, list(content))
        pe_sec.virtual_size = len(content)
        pe_sec.characteristics = flags
        pe_factory.add_section(pe_sec)


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.so output.efi")
        sys.exit(1)

    so_path = sys.argv[1]
    efi_path = sys.argv[2]

    elf = lief.ELF.parse(so_path)

    pe_factory = lief.PE.Factory.create(lief.PE.PE_TYPE.PE32_PLUS)

    keep_sections = {
        '.text', '.rodata', '.data',
        '.dynamic', '.dynsym', '.dynstr',
        '.rel.dyn', '.rela.dyn',
        '.rel.plt', '.rela.plt',
    }
    copy_sections(elf, pe_factory, keep_sections)

    reloc_size = build_reloc_section(elf, pe_factory)

    pe = pe_factory.get()

    pe.optional_header.imagebase = PE_IMAGE_BASE
    pe.header.machine = MACH.ARM64
    pe.header.add_characteristic(HCHAR.EXECUTABLE_IMAGE)
    pe.header.add_characteristic(HCHAR.LINE_NUMS_STRIPPED)
    pe.header.add_characteristic(HCHAR.LOCAL_SYMS_STRIPPED)

    pe.optional_header.subsystem = SUBSYS.EFI_APPLICATION
    pe.optional_header.magic = lief.PE.PE_TYPE.PE32_PLUS
    pe.optional_header.major_image_version = 1
    pe.optional_header.minor_image_version = 0
    pe.optional_header.sizeof_stack_reserve = 0x100000
    pe.optional_header.sizeof_stack_commit = 0x1000
    pe.optional_header.sizeof_heap_reserve = 0x100000
    pe.optional_header.sizeof_heap_commit = 0x1000

    if reloc_size is not None:
        for s in pe.sections:
            if s.name == '.reloc':
                pe.data_directories[
                    DD_TYPES.BASE_RELOCATION_TABLE.value
                ].rva = s.virtual_address
                pe.data_directories[
                    DD_TYPES.BASE_RELOCATION_TABLE.value
                ].size = reloc_size
                break

    sym = elf.get_symbol('_start') or elf.get_symbol('efi_main')
    if sym:
        for pe_sec in pe.sections:
            if pe_sec.name == '.text':
                pe.optional_header.addressof_entrypoint = pe_sec.virtual_address + sym.value
                break

    pe.write(efi_path)
    print(f"Written: {efi_path}")


if __name__ == '__main__':
    main()
