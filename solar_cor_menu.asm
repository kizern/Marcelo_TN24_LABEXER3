; SOLAR / COR menu -- NASM, 32-bit Linux, int 0x80 (no C library).
; Build: nasm -f elf32 solar.asm -o solar.o
;        ld -m elf_i386 solar.o -o solar
; Run:   ./solar
; Write replaces the chosen file. Read displays bytes; it does not import records.
BITS 32

global _start

%define SYS_EXIT       1
%define SYS_READ       3
%define SYS_WRITE      4
%define SYS_OPEN       5
%define SYS_CLOSE      6
%define O_WRONLY_CREATE_TRUNC 577 ; O_WRONLY | O_CREAT | O_TRUNC
%define FILE_MODE      0o600
%define FIELD_SIZE     96
%define UNIT_PRICE     1000
%define LAB_PRICE      2500
%define MAX_UNITS      30

%macro PRINT 1
    push eax
    mov eax, %1
    call print_string
    pop eax
%endmacro

%macro PRINT_NUMBER 1
    push eax
    mov eax, %1
    call print_uint
    pop eax
%endmacro

%macro ASK_TEXT 3
    ; Arguments: prompt address, buffer address, buffer capacity.
    push ebx
    push ecx
    push edx
    mov ebx, %1
    mov ecx, %2
    mov edx, %3
    call ask_text
    pop edx
    pop ecx
    pop ebx
%endmacro

SECTION .data
    menu db 10, '========================================', 10
         db '                  COR', 10
         db '========================================', 10
         db '1. Input  - Enter student details and subject units', 10
         db '2. Output - Display the full information', 10
         db '3. Write  - Write the full details into a file', 10
         db '4. Read   - Read the contents of a file', 10
         db '5. Exit', 10
         db 'Enter your choice: ', 0
    bad_choice db 'Invalid choice. Enter 1, 2, 3, 4, or 5.', 10, 0
    no_record db 'Please use option 1 to enter a complete record first.', 10, 0
    input_done db 'Record completed. Fees calculated.', 10, 0
    file_prompt db 'Filename/path (1-95 characters; Write replaces existing file): ', 0
    open_failed db 'Could not open the file. Check the path and permissions.', 10, 0
    write_failed db 'Could not finish writing the file; it may be incomplete.', 10, 0
    read_failed db 'Could not finish reading/closing the file.', 10, 0
    saved db 'Full report saved successfully.', 10, 0
    file_heading db 10, '---------- FILE CONTENTS ----------', 10, 0
    file_end db 10, '---------- END OF FILE ----------', 10, 0
    goodbye db 'Goodbye!', 10, 0
    output_fd dd 1
    output_error dd 0
    record_ready db 0
    banner db 10, '========== SOLAR ENROLLMENT ==========', 10, 0
    info_heading db 10, '---------- STUDENT INFORMATION ----------', 10, 0
    subject_heading db 10, '---------- SUBJECT UNIT ENTRY ----------', 10
                    db 'Enter whole units (0-30); 0 means not enrolled.', 10
                    db 'Tuition: PHP 1000/unit. Laboratory: PHP 2500 per enrolled lab subject.', 10, 0
    assessment_heading db 10, '---------- ENROLLMENT SUMMARY ----------', 10, 0
    fee_heading db 10, '---------- TUITION ASSESSMENT ----------', 10, 0
    newline db 10, 0
    separator db '. ', 0
    units_suffix db ' | Units: ', 0
    unit_prompt db 'Number of units: ', 0
    invalid_text db 'Please enter 1-95 characters.', 10, 0
    invalid_units db 'Invalid units. Enter a whole number from 0 to 30.', 10, 0
    input_stopped db 10, 'Input ended or could not be read. Assessment cancelled.', 10, 0
    total_units_label db 'Total units: ', 0
    lab_count_label db 'Enrolled laboratory subjects: ', 0
    tuition_label db 'Tuition (units x PHP 1000): PHP ', 0
    lab_fee_label db 'Laboratory fees (lab subjects x PHP 2500): PHP ', 0
    total_label db 'TOTAL AMOUNT DUE: PHP ', 0
    cents db '.00', 10, 0

    p_status db 'Enrollment status: ', 0
    p_student db 'Student number: ', 0
    p_name db 'Name: ', 0
    p_phone db 'Phone: ', 0
    p_zip db 'Zip code: ', 0
    p_class db 'Classification (or N/A): ', 0
    p_college db 'College: ', 0
    p_program db 'Program: ', 0
    p_year db 'Year level: ', 0
    p_term db 'Term: ', 0
    p_school_year db 'School year: ', 0
    p_address db 'Address: ', 0

    field_prompts dd p_status, p_student, p_name, p_phone, p_zip, p_class
                  dd p_college, p_program, p_year, p_term, p_school_year, p_address
    FIELD_COUNT equ ($ - field_prompts) / 4

    s1 db 'CCS0021  - INFORMATION MANAGEMENT (LEC)', 0
    s2 db 'CCS0021L - INFORMATION MANAGEMENT (LAB)', 0
    s3 db 'CS0001   - DISCRETE STRUCTURES 1', 0
    s4 db 'CS0003   - COMPUTER SYSTEMS & ARCHITECTURE', 0
    s5 db 'CS0003L  - COMPUTER SYSTEMS & ARCHITECTURE (LAB)', 0
    s6 db 'CS0070   - OBJECT ORIENTED PROGRAMMING', 0
    s7 db 'CS0070L  - OBJECT ORIENTED PROGRAMMING-LAB', 0
    s8 db 'GED0021  - SPECIALIZED ENGLISH PROGRAM 2', 0
    s9 db 'GED0055  - MATHEMATICAL ANALYSIS', 0
    s10 db 'GED0081  - COLLEGE PHYSICS 1 LECTURE', 0
    s11 db 'GED0081L - COLLEGE PHYSICS 1 LABORATORY', 0

    subjects dd s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11
    SUBJECT_COUNT equ ($ - subjects) / 4
    is_lab db 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1

SECTION .bss
    filename resb FIELD_SIZE
    file_buffer resb 4096
    student_info resb FIELD_COUNT * FIELD_SIZE
    subject_units resd SUBJECT_COUNT
    input_buffer resb FIELD_SIZE
    input_char resb 1
    number_buffer resb 11
    total_units resd 1
    lab_count resd 1
    tuition_fee resd 1
    laboratory_fee resd 1
    total_fee resd 1

SECTION .text
_start:
    PRINT banner
.menu:
    PRINT menu
    mov ecx, input_buffer
    mov edx, FIELD_SIZE
    call read_line
    cmp eax, -1
    je .exit
    cmp eax, 1
    jne .invalid
    mov al, [input_buffer]
    cmp al, '1'
    je .input
    cmp al, '2'
    je .output
    cmp al, '3'
    je .write
    cmp al, '4'
    je .read
    cmp al, '5'
    je .exit
.invalid:
    PRINT bad_choice
    jmp .menu
.input:
    mov byte [record_ready], 0
    PRINT info_heading
    call get_student_info
    call get_subject_units
    call calculate_fees
    mov byte [record_ready], 1
    PRINT input_done
    jmp .menu
.output:
    cmp byte [record_ready], 1
    jne .missing
    call display_full_report
    jmp .menu
.write:
    cmp byte [record_ready], 1
    jne .missing
    call write_report
    jmp .menu
.read:
    call read_file
    jmp .menu
.missing:
    PRINT no_record
    jmp .menu
.exit:
    PRINT goodbye
    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80

; The same report procedure serves Output and Write.
display_full_report:
    PRINT banner
    call display_student_info
    call display_assessment
    ret

write_report:
    pushad
    ASK_TEXT file_prompt, filename, FIELD_SIZE
.open:
    mov eax, SYS_OPEN
    mov ebx, filename
    mov ecx, O_WRONLY_CREATE_TRUNC
    mov edx, FILE_MODE
    int 0x80
    cmp eax, -4                  ; Interrupted syscall: retry.
    je .open
    test eax, eax
    js .open_error
    mov [output_fd], eax
    mov dword [output_error], 0
    call display_full_report
    mov ebx, [output_fd]
    mov dword [output_fd], 1     ; Restore console before any status message.
    mov eax, SYS_CLOSE
    int 0x80                    ; Do not retry close on Linux.
    test eax, eax
    js .write_error
    cmp dword [output_error], 0
    jne .write_error
    PRINT saved
    jmp .done
.open_error:
    PRINT open_failed
    jmp .done
.write_error:
    PRINT write_failed
.done:
    popad
    ret

read_file:
    pushad
    ASK_TEXT file_prompt, filename, FIELD_SIZE
.open:
    mov eax, SYS_OPEN
    mov ebx, filename
    xor ecx, ecx                ; O_RDONLY; never creates a missing file.
    xor edx, edx
    int 0x80
    cmp eax, -4
    je .open
    test eax, eax
    js .open_error
    mov esi, eax
    PRINT file_heading
.next:
    mov eax, SYS_READ
    mov ebx, esi
    mov ecx, file_buffer
    mov edx, 4096
    int 0x80
    cmp eax, -4
    je .next
    test eax, eax
    js .read_error
    jz .finished
    mov edx, eax                ; Write exact byte count, including NUL bytes.
    mov ecx, file_buffer
    mov ebx, 1
    call write_all
    test eax, eax
    js .read_error
    jmp .next
.finished:
    mov eax, SYS_CLOSE
    mov ebx, esi
    int 0x80
    test eax, eax
    js .report_error
    PRINT file_end
    jmp .done
.read_error:
    mov eax, SYS_CLOSE
    mov ebx, esi
    int 0x80
.report_error:
    PRINT read_failed
    jmp .done
.open_error:
    PRINT open_failed
.done:
    popad
    ret

; EBX = descriptor, ECX = bytes, EDX = count.
; Returns EAX = 0 on success, -1 on error; handles partial writes and EINTR.
write_all:
.next:
    test edx, edx
    jz .done
    mov eax, SYS_WRITE
    int 0x80
    cmp eax, -4
    je .next
    test eax, eax
    jle .failed
    add ecx, eax
    sub edx, eax
    jmp .next
.done:
    xor eax, eax
    ret
.failed:
    mov eax, -1
    ret

get_student_info:
    pushad
    xor esi, esi
.next:
    imul edi, esi, FIELD_SIZE
    add edi, student_info
    ASK_TEXT [field_prompts + esi*4], edi, FIELD_SIZE
    inc esi
    cmp esi, FIELD_COUNT
    jb .next
    popad
    ret

display_student_info:
    pushad
    PRINT info_heading
    xor esi, esi
.next:
    PRINT [field_prompts + esi*4]
    imul edi, esi, FIELD_SIZE
    add edi, student_info
    PRINT edi
    PRINT newline
    inc esi
    cmp esi, FIELD_COUNT
    jb .next
    popad
    ret

get_subject_units:
    pushad
    PRINT subject_heading
    xor esi, esi
.next:
    PRINT newline
    lea eax, [esi + 1]
    PRINT_NUMBER eax
    PRINT separator
    PRINT [subjects + esi*4]
    PRINT newline
    call read_units
    mov [subject_units + esi*4], eax
    inc esi
    cmp esi, SUBJECT_COUNT
    jb .next
    popad
    ret

read_units:
    push ebx
    push ecx
    push edx
    push esi
.retry:
    ASK_TEXT unit_prompt, input_buffer, FIELD_SIZE
    mov esi, input_buffer
    xor eax, eax
.digit:
    movzx edx, byte [esi]
    test edx, edx
    jz .done
    cmp edx, '0'
    jb .invalid
    cmp edx, '9'
    ja .invalid
    sub edx, '0'
    imul eax, eax, 10
    add eax, edx
    cmp eax, MAX_UNITS
    ja .invalid
    inc esi
    jmp .digit
.invalid:
    PRINT invalid_units
    jmp .retry
.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

calculate_fees:
    pushad
    mov dword [total_units], 0
    mov dword [lab_count], 0
    xor esi, esi
.next:
    mov eax, [subject_units + esi*4]
    add [total_units], eax
    test eax, eax
    jz .skip_lab
    cmp byte [is_lab + esi], 1
    jne .skip_lab
    inc dword [lab_count]
.skip_lab:
    inc esi
    cmp esi, SUBJECT_COUNT
    jb .next
    mov eax, [total_units]
    imul eax, eax, UNIT_PRICE
    mov [tuition_fee], eax
    mov edx, [lab_count]
    imul edx, edx, LAB_PRICE
    mov [laboratory_fee], edx
    add eax, edx
    mov [total_fee], eax
    popad
    ret

display_assessment:
    pushad
    PRINT assessment_heading
    xor esi, esi
.next:
    PRINT [subjects + esi*4]
    PRINT units_suffix
    PRINT_NUMBER [subject_units + esi*4]
    PRINT newline
    inc esi
    cmp esi, SUBJECT_COUNT
    jb .next
    PRINT fee_heading
    PRINT total_units_label
    PRINT_NUMBER [total_units]
    PRINT newline
    PRINT lab_count_label
    PRINT_NUMBER [lab_count]
    PRINT newline
    PRINT tuition_label
    PRINT_NUMBER [tuition_fee]
    PRINT cents
    PRINT lab_fee_label
    PRINT_NUMBER [laboratory_fee]
    PRINT cents
    PRINT total_label
    PRINT_NUMBER [total_fee]
    PRINT cents
    popad
    ret

ask_text:
    push ebx
    push ecx
    push edx
.retry:
    PRINT ebx
    call read_line
    cmp eax, -1
    je input_error
    cmp eax, 0
    jle .invalid
    pop edx
    pop ecx
    pop ebx
    ret
.invalid:
    PRINT invalid_text
    jmp .retry

read_line:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov edi, ecx
    mov ebp, edx
    dec ebp
    xor esi, esi
.read:
    mov eax, SYS_READ
    xor ebx, ebx
    mov ecx, input_char
    mov edx, 1
    int 0x80
    cmp eax, -4
    je .read
    test eax, eax
    js .error
    jz .eof
    mov al, [input_char]
    cmp al, 10
    je .finished
    cmp al, 13
    je .read
    test al, al                ; Reject embedded NUL; drain the entire line.
    jz .overflow
    cmp esi, ebp
    jae .overflow
    mov [edi + esi], al
    inc esi
    jmp .read
.overflow:
    lea esi, [ebp + 1]
    jmp .read
.eof:
    test esi, esi
    jz .error
.finished:
    cmp esi, ebp
    ja .too_long
    mov byte [edi + esi], 0
    mov eax, esi
    jmp .return
.too_long:
    mov byte [edi + ebp], 0
    mov eax, -2
    jmp .return
.error:
    mov eax, -1
.return:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

print_string:
    pushad
    mov ecx, eax
    xor edx, edx
.length:
    cmp byte [ecx + edx], 0
    je .write
    inc edx
    jmp .length
.write:
    mov ebx, [output_fd]
    call write_all
    test eax, eax
    js .failed
.done:
    popad
    ret
.failed:
    cmp dword [output_fd], 1
    je .console_failed
    mov dword [output_error], 1
    jmp .done
.console_failed:
    mov eax, SYS_EXIT
    mov ebx, 1
    int 0x80

print_uint:
    pushad
    mov edi, number_buffer + 10
    mov byte [edi], 0
    mov ebx, 10
.convert:
    xor edx, edx
    div ebx
    add dl, '0'
    dec edi
    mov [edi], dl
    test eax, eax
    jnz .convert
    mov eax, edi
    call print_string
    popad
    ret

input_error:
    PRINT input_stopped
    mov eax, SYS_EXIT
    mov ebx, 1
    int 0x80
