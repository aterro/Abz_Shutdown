#!/usr/bin/env python3
"""Convert ELF .so (GNU-EFI build) to PE/COFF EFI file. Zero dependencies."""

import struct
import sys

# --- Constants ---
PE_MACHINE_ARM64 = 0xAA64
PE_FILE_ALIGN = 0x200
PE_SECTION_ALIGN = 0x1000
PE_IMAGE_BASE = 0x10000000
PE_SUBSYSTEM_EFI_APPLICATION = 10
SECT_CHAR_MASK = {
    'TEXT': 0x60000020,  # CNT_CODE | MEM_EXECUTE | MEM_READ
    'DATA': 0xC0000040,  # CNT_INIT_DATA | MEM_READ | MEM_WRITE
    'RO':   0x40000040,  # CNT_INIT_DATA | MEM_READ
    'RELOC':0x42000040,  # CNT_INIT_DATA | MEM_READ | MEM_DISCARDABLE
}
RELOC_BASE_DIR64 = 0xA
KEEP_SECTIONS = {'.text', '.rodata', '.data', '.dynamic', '.dynsym', '.dynstr'}


def align_up(v, a):
    return (v + a - 1) & ~(a - 1)


# ---- ELF parsing -------------------------------------------------

def read_elf_sections(data):
    if data[:4] != b'\x7fELF':
        raise ValueError('Not an ELF file')

    # Parse ELF64 header
    e_entry = struct.unpack_from('<Q', data, 24)[0]
    e_shoff = struct.unpack_from('<Q', data, 40)[0]
    e_shentsize = struct.unpack_from('<H', data, 58)[0]
    e_shnum = struct.unpack_from('<H', data, 60)[0]
    e_shstrndx = struct.unpack_from('<H', data, 62)[0]

    # Read section headers
    sections = []
    for i in range(e_shnum):
        off = e_shoff + i * e_shentsize
        sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size = \
            struct.unpack_from('<IIQQQQ', data, off)
        sections.append({
            'idx': i,
            'name_idx': sh_name,
            'type': sh_type,
            'flags': sh_flags,
            'addr': sh_addr,
            'offset': sh_offset,
            'size': sh_size,
            'data': data[sh_offset:sh_offset + sh_size],
        })

    # Read section name string table
    if e_shstrndx < len(sections):
        s = sections[e_shstrndx]
        strtab = s['data']
        for sec in sections:
            end = strtab.find(b'\0', sec['name_idx'])
            sec['name'] = strtab[sec['name_idx']:end].decode('latin-1')

    return sections, e_entry


def elf_section_by_name(sections, name):
    for s in sections:
        if s.get('name') == name:
            return s
    return None


def elf_symbols(sections):
    """Return list of symbols from .symtab or .dynsym."""
    symsec = elf_section_by_name(sections, '.symtab') or elf_section_by_name(sections, '.dynsym')
    if not symsec:
        return []
    d = symsec['data']
    entsize = 24  # ELF64 symbol
    symbols = []
    strsec = None
    # Find the associated string table
    for s in sections:
        if s.get('name') == '.strtab' or s.get('name') == '.dynstr':
            strsec = s
            break
    st = strsec['data'] if strsec else b''
    for i in range(0, len(d), entsize):
        if i + entsize > len(d):
            break
        st_name, st_info, st_other, st_shndx, st_value, st_size = \
            struct.unpack_from('<IBBHQQ', d, i)
        name = ''
        if st_name < len(st):
            end = st.find(b'\0', st_name)
            name = st[st_name:end].decode('latin-1')
        symbols.append({
            'name': name,
            'info': st_info,
            'other': st_other,
            'shndx': st_shndx,
            'value': st_value,
            'size': st_size,
        })
    return symbols


def elf_relocations(sections):
    """Collect R_AARCH64_RELATIVE relocations from .rela* sections."""
    relocs = []
    for s in sections:
        name = s.get('name', '')
        if not name.startswith('.rela'):
            continue
        d = s['data']
        entsize = 24  # ELF64 rela
        for i in range(0, len(d), entsize):
            if i + entsize > len(d):
                break
            r_offset, r_info, r_addend = struct.unpack_from('<QQQ', d, i)
            r_type = r_info & 0xFFFFFFFF
            if r_type == 1027:  # R_AARCH64_RELATIVE
                relocs.append(r_offset)
            elif r_type == 257:  # R_AARCH64_ABS64
                relocs.append(r_offset)
    return sorted(set(relocs))


# ---- PE building -------------------------------------------------

def pe_section_header(name, vsize, vaddr, raw_size, raw_off, chars):
    name_bytes = name.encode()[:8].ljust(8, b'\0')
    return struct.pack('<8sIIIIIHHII',
        name_bytes, vsize, vaddr, raw_size, raw_off,
        0, 0, 0, 0, chars)


def build_pe(sections_data, reloc_blocks, text_va, entry_va):
    """Build complete PE/COFF EFI file as bytes."""
    num_secs = len(sections_data)
    if reloc_blocks:
        num_secs += 1

    # Calculate header sizes
    dos_stub_size = 64
    coff_hdr_off = 64 + dos_stub_size  # 0x80
    opt_hdr_off = coff_hdr_off + 20
    opt_hdr_size = 112 + 16 * 8  # 240
    sec_hdrs_off = opt_hdr_off + opt_hdr_size
    raw_hdrs_size = sec_hdrs_off + num_secs * 40
    hdrs_size = align_up(raw_hdrs_size, PE_FILE_ALIGN)

    # Lay out sections: assign RVAs and file offsets
    next_rva = PE_SECTION_ALIGN  # first section RVA
    next_file_off = hdrs_size

    for sd in sections_data:
        sd['rva'] = next_rva
        sd['file_off'] = next_file_off
        raw = len(sd['content'])
        sd['raw_size'] = align_up(raw, PE_FILE_ALIGN)
        next_rva += PE_SECTION_ALIGN
        next_file_off += sd['raw_size']

    if reloc_blocks:
        reloc_data = bytearray()
        for page_start, block_size, entries in reloc_blocks:
            reloc_data.extend(page_start.to_bytes(4, 'little'))
            reloc_data.extend(block_size.to_bytes(4, 'little'))
            for e in entries:
                reloc_data.extend(e.to_bytes(2, 'little'))
            while len(reloc_data) % 4 != 0:
                reloc_data.extend(b'\x00\x00')
        reloc_raw = len(reloc_data)
        reloc_rva = next_rva
        reloc_file_off = next_file_off
        reloc_raw_size = align_up(reloc_raw, PE_FILE_ALIGN)
        next_rva += PE_SECTION_ALIGN
        next_file_off += reloc_raw_size
    else:
        reloc_data = None

    size_of_image = next_rva

    # Build headers
    buf = bytearray()

    # DOS header
    buf += b'MZ' + b'\0' * 62
    struct.pack_into('<I', buf, 60, coff_hdr_off)  # e_lfanew

    # DOS stub
    buf += b'\0' * dos_stub_size

    # COFF header
    buf += struct.pack('<HHIIIHH',
        PE_MACHINE_ARM64,
        num_secs,
        0x00000000,  # TimeDateStamp
        0,           # PointerToSymbolTable
        0,           # NumberOfSymbols
        opt_hdr_size,
        0x020E,      # Characteristics
    )

    # Optional header PE32+
    # Standard fields
    buf += struct.pack('<HBBIII',
        0x020B,      # Magic PE32+
        0,           # MajorLinkerVersion
        0,           # MinorLinkerVersion
        0,           # SizeOfCode
        0,           # SizeOfInitData
        0,           # SizeOfUninitData
    )
    buf += struct.pack('<II',
        entry_va,    # AddressOfEntryPoint
        text_va,     # BaseOfCode
    )
    # NT additional fields (PE32+)
    buf += struct.pack('<QIIHHHHHH',
        PE_IMAGE_BASE,
        PE_SECTION_ALIGN,
        PE_FILE_ALIGN,
        1,           # MajorOSVersion
        0,           # MinorOSVersion
        1,           # MajorImageVersion
        0,           # MinorImageVersion
        0,           # MajorSubsystemVersion
        0,           # MinorSubsystemVersion
    )
    buf += struct.pack('<IIIIHH',
        0,           # Win32VersionValue
        size_of_image,
        hdrs_size,
        0,           # CheckSum
        PE_SUBSYSTEM_EFI_APPLICATION,
        0,           # DllCharacteristics
    )
    buf += struct.pack('<QQQQ',
        0x100000,    # SizeOfStackReserve
        0x1000,      # SizeOfStackCommit
        0x100000,    # SizeOfHeapReserve
        0x1000,      # SizeOfHeapCommit
    )
    buf += struct.pack('<II',
        0,           # LoaderFlags
        16,          # NumberOfRvaAndSizes
    )

    # Data directories (16 entries)
    for i in range(16):
        if reloc_data and i == 5:  # BASERELOC
            buf += struct.pack('<II', reloc_rva, reloc_raw)
        else:
            buf += struct.pack('<II', 0, 0)

    # Section headers
    for sd in sections_data:
        buf += pe_section_header(
            sd['name'], len(sd['content']), sd['rva'],
            sd['raw_size'], sd['file_off'], sd['chars'])

    if reloc_data:
        buf += pe_section_header(
            '.reloc', reloc_raw, reloc_rva,
            reloc_raw_size, reloc_file_off, SECT_CHAR_MASK['RELOC'])

    # Pad to hdrs_size
    buf += b'\0' * (hdrs_size - len(buf))

    # Write section data
    for sd in sections_data:
        buf += sd['content']
        buf += b'\0' * (sd['raw_size'] - len(sd['content']))

    if reloc_data:
        buf += bytes(reloc_data)
        buf += b'\0' * (reloc_raw_size - reloc_raw)

    return bytes(buf)


# ---- Main --------------------------------------------------------

def main():
    if len(sys.argv) != 3:
        print(f'Usage: {sys.argv[0]} input.so output.efi')
        sys.exit(1)

    with open(sys.argv[1], 'rb') as f:
        elf_data = f.read()

    sections, e_entry = read_elf_sections(elf_data)

    keep = [s for s in sections if s.get('name') in KEEP_SECTIONS and s.get('data')]
    if not keep:
        print('ERROR: no relevant sections found in ELF')
        sys.exit(1)

    sectext = elf_section_by_name(sections, '.text')
    if not sectext:
        print('ERROR: no .text section')
        sys.exit(1)

    # Collect relocations
    reloc_addrs = elf_relocations(sections)

    # Build .reloc blocks
    reloc_blocks = None
    if reloc_addrs:
        blocks = []
        i = 0
        while i < len(reloc_addrs):
            page = reloc_addrs[i] & ~0xFFF
            entries = []
            while i < len(reloc_addrs) and (reloc_addrs[i] & ~0xFFF) == page:
                entries.append((RELOC_BASE_DIR64 << 12) | (reloc_addrs[i] & 0xFFF))
                i += 1
            bsize = align_up(8 + len(entries) * 2, 4)
            while len(entries) * 2 + 8 < bsize:
                entries.append(0x0000)
                bsize = align_up(8 + len(entries) * 2, 4)
            blocks.append((page, bsize, entries))
        reloc_blocks = blocks

    # Determine characteristics per section
    secs_data = []
    for s in keep:
        name = s['name']
        if name == '.text':
            chars = SECT_CHAR_MASK['TEXT']
        elif name == '.data':
            chars = SECT_CHAR_MASK['DATA']
        else:
            chars = SECT_CHAR_MASK['RO']
        secs_data.append({
            'name': name,
            'content': s['data'],
            'chars': chars,
        })

    # Entry point from ELF header e_entry
    entry_off = e_entry - sectext['addr']  # offset within .text section

    text_va = PE_SECTION_ALIGN  # First section gets RVA = SectionAlignment
    entry_va = text_va + entry_off

    pe_data = build_pe(secs_data, reloc_blocks, text_va, entry_va)

    with open(sys.argv[2], 'wb') as f:
        f.write(pe_data)

    ok = pe_data[:2] == b'MZ'
    print(f'Written: {sys.argv[2]} ({len(pe_data)} bytes) - {"OK (MZ)" if ok else "WARN: no MZ header"}')


if __name__ == '__main__':
    main()
