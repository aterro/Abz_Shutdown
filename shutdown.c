#include <efi.h>
#include <efilib.h>

// ACPI-related defines and structs (from refind/main.c)
#define ACPI_RSDP_SIGNATURE        "RSD PTR "
#define ACPI_FADT_SIGNATURE        "FACP"
#define ACPI_DSDT_SIGNATURE        "DSDT"
#define ACPI_SSDT_SIGNATURE        "SSDT"
#define ACPI_SLP_EN                (1 << 13)
#define ACPI_SLP_TYP_OFFSET        10

enum {
    ACPI_OPCODE_ZERO               = 0x00,
    ACPI_OPCODE_ONE                = 0x01,
    ACPI_OPCODE_ALIAS              = 0x06,
    ACPI_OPCODE_NAME               = 0x08,
    ACPI_OPCODE_BYTE_CONST         = 0x0A,
    ACPI_OPCODE_WORD_CONST         = 0x0B,
    ACPI_OPCODE_DWORD_CONST        = 0x0C,
    ACPI_OPCODE_STRING_CONST       = 0x0D,
    ACPI_OPCODE_SCOPE              = 0x10,
    ACPI_OPCODE_BUFFER             = 0x11,
    ACPI_OPCODE_PACKAGE            = 0x12,
    ACPI_OPCODE_METHOD             = 0x14,
    ACPI_OPCODE_EXTOP              = 0x5B,
    ACPI_OPCODE_ADD                = 0x72,
    ACPI_OPCODE_CONCAT             = 0x73,
    ACPI_OPCODE_SUBTRACT           = 0x74,
    ACPI_OPCODE_MULTIPLY           = 0x77,
    ACPI_OPCODE_DIVIDE             = 0x78,
    ACPI_OPCODE_LSHIFT             = 0x79,
    ACPI_OPCODE_RSHIFT             = 0x7A,
    ACPI_OPCODE_AND                = 0x7B,
    ACPI_OPCODE_NAND               = 0x7C,
    ACPI_OPCODE_OR                 = 0x7D,
    ACPI_OPCODE_NOR                = 0x7E,
    ACPI_OPCODE_XOR                = 0x7F,
    ACPI_OPCODE_CONCATRES          = 0x84,
    ACPI_OPCODE_MOD                = 0x85,
    ACPI_OPCODE_INDEX              = 0x88,
    ACPI_OPCODE_CREATE_DWORD_FIELD = 0x8A,
    ACPI_OPCODE_CREATE_WORD_FIELD  = 0x8B,
    ACPI_OPCODE_CREATE_BYTE_FIELD  = 0x8C,
    ACPI_OPCODE_TOSTRING           = 0x9C,
    ACPI_OPCODE_IF                 = 0xA0,
    ACPI_OPCODE_ONES               = 0xFF
};

enum {
    ACPI_EXTOPCODE_MUTEX            = 0x01,
    ACPI_EXTOPCODE_EVENT_OP         = 0x02,
    ACPI_EXTOPCODE_OPERATION_REGION = 0x80,
    ACPI_EXTOPCODE_FIELD_OP         = 0x81,
    ACPI_EXTOPCODE_DEVICE_OP        = 0x82,
    ACPI_EXTOPCODE_PROCESSOR_OP     = 0x83,
    ACPI_EXTOPCODE_POWER_RES_OP     = 0x84,
    ACPI_EXTOPCODE_THERMAL_ZONE_OP  = 0x85,
    ACPI_EXTOPCODE_INDEX_FIELD_OP   = 0x86,
    ACPI_EXTOPCODE_BANK_FIELD_OP    = 0x87
};

typedef struct __attribute__((packed)) {
    CHAR8   Signature[8];
    UINT8   Checksum;
    CHAR8   OemId[6];
    UINT8   Revision;
    UINT32  RsdtAddress;
} SHUTDOWN_ACPI_RSDP_V10;

typedef struct __attribute__((packed)) {
    SHUTDOWN_ACPI_RSDP_V10 RsdpV1;
    UINT32               Length;
    UINT64               XsdtAddress;
    UINT8                ExtendedChecksum;
    UINT8                Reserved[3];
} SHUTDOWN_ACPI_RSDP_V20;

typedef struct __attribute__((packed)) {
    CHAR8   Signature[4];
    UINT32  Length;
    UINT8   Revision;
    UINT8   Checksum;
    CHAR8   OemId[6];
    CHAR8   OemTableId[8];
    UINT32  OemRevision;
    CHAR8   CreatorId[4];
    UINT32  CreatorRevision;
} SHUTDOWN_ACPI_TABLE_HEADER;

typedef struct __attribute__((packed)) {
    SHUTDOWN_ACPI_TABLE_HEADER Header;
    UINT32                   FacsAddress;
    UINT32                   DsdtAddress;
    UINT8                    Reserved1[20];
    UINT32                   Pm1aControlBlock;
    UINT8                    Reserved2[8];
    UINT32                   PmTimerBlock;
    UINT8                    Reserved3[32];
    UINT32                   Flags;
    UINT8                    Reserved4[16];
    UINT64                   XFacsAddress;
    UINT64                   XDsdtAddress;
    UINT8                    Reserved5[96];
} SHUTDOWN_ACPI_FADT;

static EFI_GUID ShutdownAcpi20TableGuid = { 0x8868e871, 0xe4f1, 0x11d3, { 0xbc, 0x22, 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 } };
static EFI_GUID ShutdownAcpi10TableGuid = { 0xeb9d2d30, 0x2d88, 0x11d3, { 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d } };

static BOOLEAN GuidsAreEqual(EFI_GUID *Guid1, EFI_GUID *Guid2) {
    return (CompareMem(Guid1, Guid2, sizeof(EFI_GUID)) == 0);
}

static UINT32 AcpiDecodeLength(const UINT8 *Ptr, INTN *NumLen);
static UINT32 AcpiSkipNameString(const UINT8 *Ptr, const UINT8 *End);
static UINT32 AcpiSkipDataRefObject(const UINT8 *Ptr, const UINT8 *End);
static UINT32 AcpiSkipTerm(const UINT8 *Ptr, const UINT8 *End);
static UINT32 AcpiSkipExtOp(const UINT8 *Ptr, const UINT8 *End);
static INTN AcpiGetSleepType(UINT8 *Table, UINT8 *Ptr, UINT8 *End, UINT8 *Scope, INTN ScopeLen);
static VOID AcpiWritePmControl(UINT16 Port, UINT16 Value);
static VOID *FindAcpiRootPointer(VOID);
static BOOLEAN TryAcpiShutdown(VOID);

static UINT32 AcpiDecodeLength(const UINT8 *Ptr, INTN *NumLen) {
    INTN   NumBytes, Index;
    UINT32 Value;

    if (*Ptr < 64) {
        if (NumLen != NULL)
            *NumLen = 1;
        return *Ptr;
    }

    NumBytes = *Ptr >> 6;
    if (NumLen != NULL)
        *NumLen = NumBytes + 1;
    Value = *Ptr & 0x0F;
    Ptr++;

    for (Index = 0; Index < NumBytes; Index++) {
        Value |= ((UINT32) Ptr[Index]) << (8 * Index + 4);
    }

    return Value;
}

static UINT32 AcpiSkipNameString(const UINT8 *Ptr, const UINT8 *End) {
    const UINT8 *Start = Ptr;

    while (Ptr < End && (*Ptr == '^' || *Ptr == '\\'))
        Ptr++;
    if (Ptr >= End)
        return 0;

    switch (*Ptr) {
        case '.':
            Ptr++;
            Ptr += 8;
            break;
        case '/':
            Ptr++;
            if (Ptr >= End)
                return 0;
            Ptr += 1 + (*Ptr) * 4;
            break;
        case 0:
            Ptr++;
            break;
        default:
            Ptr += 4;
            break;
    }

    if (Ptr > End)
        return 0;
    return (UINT32) (Ptr - Start);
}

static UINT32 AcpiSkipDataRefObject(const UINT8 *Ptr, const UINT8 *End) {
    const UINT8 *Start = Ptr;

    if (Ptr >= End)
        return 0;

    switch (*Ptr) {
        case ACPI_OPCODE_PACKAGE:
        case ACPI_OPCODE_BUFFER:
            return 1 + AcpiDecodeLength(Ptr + 1, NULL);
        case ACPI_OPCODE_ZERO:
        case ACPI_OPCODE_ONES:
        case ACPI_OPCODE_ONE:
            return 1;
        case ACPI_OPCODE_BYTE_CONST:
            return 2;
        case ACPI_OPCODE_WORD_CONST:
            return 3;
        case ACPI_OPCODE_DWORD_CONST:
            return 5;
        case ACPI_OPCODE_STRING_CONST:
            Ptr++;
            while (Ptr < End && *Ptr)
                Ptr++;
            if (Ptr == End)
                return 0;
            return (UINT32) (Ptr - Start + 1);
        default:
            if (*Ptr == '^' || *Ptr == '\\' || *Ptr == '_' || (*Ptr >= 'A' && *Ptr <= 'Z'))
                return AcpiSkipNameString(Ptr, End);
            return 0;
    }
}

static UINT32 AcpiSkipTerm(const UINT8 *Ptr, const UINT8 *End) {
    const UINT8 *Start = Ptr;
    UINT32      Add;

    if (Ptr >= End)
        return 0;

    switch (*Ptr) {
        case ACPI_OPCODE_ADD:
        case ACPI_OPCODE_AND:
        case ACPI_OPCODE_CONCAT:
        case ACPI_OPCODE_CONCATRES:
        case ACPI_OPCODE_DIVIDE:
        case ACPI_OPCODE_INDEX:
        case ACPI_OPCODE_LSHIFT:
        case ACPI_OPCODE_MOD:
        case ACPI_OPCODE_MULTIPLY:
        case ACPI_OPCODE_NAND:
        case ACPI_OPCODE_NOR:
        case ACPI_OPCODE_OR:
        case ACPI_OPCODE_RSHIFT:
        case ACPI_OPCODE_SUBTRACT:
        case ACPI_OPCODE_TOSTRING:
        case ACPI_OPCODE_XOR:
            Ptr++;
            Add = AcpiSkipTerm(Ptr, End);
            if (!Add)
                return 0;
            Ptr += Add;
            Add = AcpiSkipTerm(Ptr, End);
            if (!Add)
                return 0;
            Ptr += Add;
            Add = AcpiSkipNameString(Ptr, End);
            if (!Add)
                return 0;
            Ptr += Add;
            break;
        default:
            return AcpiSkipDataRefObject(Ptr, End);
    }

    return (UINT32) (Ptr - Start);
}

static UINT32 AcpiSkipExtOp(const UINT8 *Ptr, const UINT8 *End) {
    const UINT8 *Start = Ptr;
    UINT32      Add;

    if (Ptr >= End)
        return 0;

    switch (*Ptr) {
        case ACPI_EXTOPCODE_MUTEX:
            Ptr++;
            Add = AcpiSkipNameString(Ptr, End);
            if (!Add || Ptr + Add >= End)
                return 0;
            Ptr += Add + 1;
            break;
        case ACPI_EXTOPCODE_EVENT_OP:
            Ptr++;
            Add = AcpiSkipNameString(Ptr, End);
            if (!Add)
                return 0;
            Ptr += Add;
            break;
        case ACPI_EXTOPCODE_OPERATION_REGION:
            Ptr++;
            Add = AcpiSkipNameString(Ptr, End);
            if (!Add || Ptr + Add >= End)
                return 0;
            Ptr += Add + 1;
            Add = AcpiSkipTerm(Ptr, End);
            if (!Add)
                return 0;
            Ptr += Add;
            Add = AcpiSkipTerm(Ptr, End);
            if (!Add)
                return 0;
            Ptr += Add;
            break;
        case ACPI_EXTOPCODE_FIELD_OP:
        case ACPI_EXTOPCODE_DEVICE_OP:
        case ACPI_EXTOPCODE_PROCESSOR_OP:
        case ACPI_EXTOPCODE_POWER_RES_OP:
        case ACPI_EXTOPCODE_THERMAL_ZONE_OP:
        case ACPI_EXTOPCODE_INDEX_FIELD_OP:
        case ACPI_EXTOPCODE_BANK_FIELD_OP:
            Ptr++;
            Ptr += AcpiDecodeLength(Ptr, NULL);
            break;
        default:
            return 0;
    }

    if (Ptr > End)
        return 0;
    return (UINT32) (Ptr - Start);
}

static INTN AcpiGetSleepType(UINT8 *Table, UINT8 *Ptr, UINT8 *End, UINT8 *Scope, INTN ScopeLen) {
    UINT8 *Previous = Table;

    if (Ptr == NULL)
        Ptr = Table + sizeof (SHUTDOWN_ACPI_TABLE_HEADER);

    while (Ptr < End && Previous < Ptr) {
        UINT32 Add = 0;
        Previous = Ptr;

        switch (*Ptr) {
            case ACPI_OPCODE_EXTOP:
                Ptr++;
                Add = AcpiSkipExtOp(Ptr, End);
                if (!Add)
                    return -1;
                Ptr += Add;
                break;

            case ACPI_OPCODE_CREATE_DWORD_FIELD:
            case ACPI_OPCODE_CREATE_WORD_FIELD:
            case ACPI_OPCODE_CREATE_BYTE_FIELD:
                Ptr += 5;
                Add = AcpiSkipDataRefObject(Ptr, End);
                if (!Add)
                    return -1;
                Ptr += Add + 4;
                break;

            case ACPI_OPCODE_NAME:
                Ptr++;
                if ((!Scope || (CompareMem(Scope, "\\", ScopeLen) == 0)) &&
                    ((CompareMem(Ptr, "_S5_", 4) == 0) || (CompareMem(Ptr, "\\_S5_", 4) == 0))) {
                    INTN  LengthBytes;
                    UINT8 *SleepPtr = Ptr + AcpiSkipNameString(Ptr, End);

                    if (SleepPtr >= End || *SleepPtr != ACPI_OPCODE_PACKAGE)
                        return -1;

                    SleepPtr++;
                    AcpiDecodeLength(SleepPtr, &LengthBytes);
                    SleepPtr += LengthBytes;
                    if (SleepPtr >= End)
                        return -1;
                    SleepPtr++;
                    if (SleepPtr >= End)
                        return -1;

                    switch (*SleepPtr) {
                        case ACPI_OPCODE_ZERO:
                            return 0;
                        case ACPI_OPCODE_ONE:
                            return 1;
                        case ACPI_OPCODE_BYTE_CONST:
                            if (SleepPtr + 1 >= End)
                                return -1;
                            return SleepPtr[1];
                        default:
                            return -1;
                    }
                }

                Add = AcpiSkipNameString(Ptr, End);
                if (!Add)
                    return -1;
                Ptr += Add;
                Add = AcpiSkipDataRefObject(Ptr, End);
                if (!Add)
                    return -1;
                Ptr += Add;
                break;

            case ACPI_OPCODE_ALIAS:
                Ptr++;
                Add = AcpiSkipNameString(Ptr, End);
                if (!Add)
                    return -1;
                Ptr += Add;
                Add = AcpiSkipNameString(Ptr, End);
                if (!Add)
                    return -1;
                Ptr += Add;
                break;

            case ACPI_OPCODE_SCOPE: {
                INTN   LengthBytes, NestedSleepType, NameLen;
                UINT32 ScopeLength;
                UINT8  *Name;

                Ptr++;
                ScopeLength = AcpiDecodeLength(Ptr, &LengthBytes);
                Name = Ptr + LengthBytes;
                NameLen = (INTN) AcpiSkipNameString(Name, Ptr + ScopeLength);
                if (!NameLen)
                    return -1;
                NestedSleepType = AcpiGetSleepType(Table, Name + NameLen, Ptr + ScopeLength, Name, NameLen);
                if (NestedSleepType != -2)
                    return NestedSleepType;
                Ptr += ScopeLength;
                break;
            }

            case ACPI_OPCODE_IF:
            case ACPI_OPCODE_METHOD:
                Ptr++;
                Ptr += AcpiDecodeLength(Ptr, NULL);
                break;

            default:
                return -1;
        }
    }

    return -2;
}

static VOID AcpiWritePmControl(UINT16 Port, UINT16 Value) {
#ifdef __MAKEWITH_GNUEFI
#if defined(EFIX64) || defined(EFI32)
    __asm__ __volatile__ ("outw %0, %1" : : "a" (Value), "Nd" (Port));
#endif
#else
    IoWrite16((UINTN) Port, Value);
#endif
}

static VOID *FindAcpiRootPointer(VOID) {
    UINTN Index;

    for (Index = 0; Index < ST->NumberOfTableEntries; Index++) {
        EFI_CONFIGURATION_TABLE *ConfigTable = &(ST->ConfigurationTable[Index]);

        if (GuidsAreEqual(&(ConfigTable->VendorGuid), &ShutdownAcpi20TableGuid) ||
            GuidsAreEqual(&(ConfigTable->VendorGuid), &ShutdownAcpi10TableGuid)) {
            return ConfigTable->VendorTable;
        }
    }

    return NULL;
}

static BOOLEAN TryAcpiShutdown(VOID) {
#if defined(EFIAARCH64)
    return FALSE;
#else
    SHUTDOWN_ACPI_RSDP_V20      *Rsdp2;
    SHUTDOWN_ACPI_RSDP_V10      *Rsdp1;
    SHUTDOWN_ACPI_TABLE_HEADER  *Rsdt;
    UINT32                    *EntryPtr;
    UINT32                    Port = 0;
    INTN                      SleepType = -1;

    Rsdp2 = (SHUTDOWN_ACPI_RSDP_V20 *) FindAcpiRootPointer();
    if (Rsdp2 == NULL)
        return FALSE;

    Rsdp1 = &(Rsdp2->RsdpV1);
    if (CompareMem(Rsdp1->Signature, ACPI_RSDP_SIGNATURE, 8) != 0 || Rsdp1->RsdtAddress == 0)
        return FALSE;

    Rsdt = (SHUTDOWN_ACPI_TABLE_HEADER *) (UINTN) Rsdp1->RsdtAddress;
    if (Rsdt == NULL || CompareMem(Rsdt->Signature, "RSDT", 4) != 0)
        return FALSE;

    for (EntryPtr = (UINT32 *) (Rsdt + 1);
         EntryPtr < (UINT32 *) (((UINT8 *) Rsdt) + Rsdt->Length);
         EntryPtr++) {
        SHUTDOWN_ACPI_TABLE_HEADER *Header = (SHUTDOWN_ACPI_TABLE_HEADER *) (UINTN) (*EntryPtr);

        if (Header == NULL)
            continue;

        if (CompareMem(Header->Signature, ACPI_FADT_SIGNATURE, 4) == 0) {
            SHUTDOWN_ACPI_FADT         *Fadt = (SHUTDOWN_ACPI_FADT *) Header;
            SHUTDOWN_ACPI_TABLE_HEADER *Dsdt = (SHUTDOWN_ACPI_TABLE_HEADER *) (UINTN) Fadt->DsdtAddress;

            Port = Fadt->Pm1aControlBlock;
            if (Dsdt != NULL && CompareMem(Dsdt->Signature, ACPI_DSDT_SIGNATURE, 4) == 0 && SleepType < 0)
                SleepType = AcpiGetSleepType((UINT8 *) Dsdt, NULL, ((UINT8 *) Dsdt) + Dsdt->Length, NULL, 0);
        } else if (CompareMem(Header->Signature, ACPI_SSDT_SIGNATURE, 4) == 0 && SleepType < 0) {
            SleepType = AcpiGetSleepType((UINT8 *) Header, NULL, ((UINT8 *) Header) + Header->Length, NULL, 0);
        }
    }

    Print(L"ACPI shutdown probe: SLP_TYP=%d PM1a=0x%08x\r\n", SleepType, Port);
    if (Port && SleepType >= 0 && SleepType < 8) {
        AcpiWritePmControl((UINT16) (Port & 0xFFFF), (UINT16) (ACPI_SLP_EN | (SleepType << ACPI_SLP_TYP_OFFSET)));
        BS->Stall(1500000);
        return TRUE;
    }

    return FALSE;
#endif
}

EFI_STATUS
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    EFI_STATUS Status = EFI_SUCCESS;

    InitializeLib(ImageHandle, SystemTable);

    Print(L"Abz-Shutdown.efi - ACPI Shutdown Utility\r\n");
    Print(L"Attempting to shut down system via ACPI...\r\n");

    if (TryAcpiShutdown()) {
        Print(L"ACPI shutdown initiated successfully.\r\n");
        BS->Stall(2000000);
    } else {
        Print(L"ACPI shutdown failed or not supported.\r\n");
        Print(L"Press any key to exit...\r\n");
        WaitForSingleEvent(ST->ConIn->WaitForKey, 0);
        Status = EFI_UNSUPPORTED;
    }

    return Status;
}
