/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright 2008 Vitaly Mayatskikh <vmayatsk@redhat.com>
 * Copyright 2002 Andi Kleen, SuSE Labs.
 *
 * Functions to copy from and to user space.
 */

#include <linux/linkage.h>
#include <asm/current.h>
#include <asm/asm-offsets.h>
#include <asm/thread_info.h>
#include <asm/cpufeatures.h>
#include <asm/alternative.h>
#include <asm/asm.h>
#include <asm/smap.h>
#include <asm/export.h>


ALIGN;
.Lcopy_user_handle_tail:
	movl %edx,%ecx
1:	rep movsb
2:	mov %ecx,%eax
	ASM_CLAC
	ret

	_ASM_EXTABLE_UA(1b, 2b)
SYM_FUNC_END(.Lcopy_user_handle_tail)

.macro ALIGN_DESTINATION
	/* check for bad alignment of destination */
	movl %edi,%ecx
	andl $7,%ecx
	jz 102f				/* already aligned */
	subl $8,%ecx
	negl %ecx
	subl %ecx,%edx
100:	movb (%rsi),%al
101:	movb %al,(%rdi)
	incq %rsi
	incq %rdi
	decl %ecx
	jnz 100b
102:
	.section .fixup,"ax"
103:	addl %ecx,%edx			/* ecx is zerorest also */
	jmp .Lcopy_user_handle_tail
	.previous

	_ASM_EXTABLE_UA(100b, 103b)
	_ASM_EXTABLE_UA(101b, 103b)
	.endm


SYM_FUNC_START(__shadow_cp)
	ASM_STAC

	/* If size is less than 8 bytes, go to 4-byte copy */
	cmpl $8,%edx
	jb .L_4b_nocache_copy_entry

	/* If destination is not 8-byte aligned, "cache" copy to align it */
	ALIGN_DESTINATION

	/* Set 4x8-byte copy count and remainder */
	movl %edx,%ecx
	andl $63,%edx
	shrl $6,%ecx
	jz .L_8b_nocache_copy_entry	/* jump if count is 0 */

	/* Perform 4x8-byte nocache loop-copy */
.L_4x8b_nocache_copy_loop:
1:	movq (%rsi),%r8
2:	movq 1*8(%rsi),%r9
3:	movq 2*8(%rsi),%r10
4:	movq 3*8(%rsi),%r11
5:	movnti %r8,(%rdi)
6:	movnti %r9,1*8(%rdi)
7:	movnti %r10,2*8(%rdi)
8:	movnti %r11,3*8(%rdi)
9:	movq 4*8(%rsi),%r8
10:	movq 5*8(%rsi),%r9
11:	movq 6*8(%rsi),%r10
12:	movq 7*8(%rsi),%r11
13:	movnti %r8,4*8(%rdi)
14:	movnti %r9,5*8(%rdi)
15:	movnti %r10,6*8(%rdi)
16:	movnti %r11,7*8(%rdi)
	leaq 64(%rsi),%rsi
	leaq 64(%rdi),%rdi
	decl %ecx
	jnz .L_4x8b_nocache_copy_loop

	/* Set 8-byte copy count and remainder */
.L_8b_nocache_copy_entry:
	movl %edx,%ecx
	andl $7,%edx
	shrl $3,%ecx
	jz .L_4b_nocache_copy_entry	/* jump if count is 0 */

	/* Perform 8-byte nocache loop-copy */
.L_8b_nocache_copy_loop:
20:	movq (%rsi),%r8
21:	movnti %r8,(%rdi)
	leaq 8(%rsi),%rsi
	leaq 8(%rdi),%rdi
	decl %ecx
	jnz .L_8b_nocache_copy_loop

	/* If no byte left, we're done */
.L_4b_nocache_copy_entry:
	andl %edx,%edx
	jz .L_finish_copy

	/* If destination is not 4-byte aligned, go to byte copy: */
	movl %edi,%ecx
	andl $3,%ecx
	jnz .L_1b_cache_copy_entry

	/* Set 4-byte copy count (1 or 0) and remainder */
	movl %edx,%ecx
	andl $3,%edx
	shrl $2,%ecx
	jz .L_1b_cache_copy_entry	/* jump if count is 0 */

	/* Perform 4-byte nocache copy: */
30:	movl (%rsi),%r8d
31:	movnti %r8d,(%rdi)
	leaq 4(%rsi),%rsi
	leaq 4(%rdi),%rdi

	/* If no bytes left, we're done: */
	andl %edx,%edx
	jz .L_finish_copy

	/* Perform byte "cache" loop-copy for the remainder */
.L_1b_cache_copy_entry:
	movl %edx,%ecx
.L_1b_cache_copy_loop:
40:	movb (%rsi),%al
41:	movb %al,(%rdi)
	incq %rsi
	incq %rdi
	decl %ecx
	jnz .L_1b_cache_copy_loop

	/* Finished copying; fence the prior stores */
.L_finish_copy:
	xorl %eax,%eax
	ASM_CLAC
	ret

	.section .fixup,"ax"
.L_fixup_4x8b_copy:
	shll $6,%ecx
	addl %ecx,%edx
	jmp .L_fixup_handle_tail
.L_fixup_8b_copy:
	lea (%rdx,%rcx,8),%rdx
	jmp .L_fixup_handle_tail
.L_fixup_4b_copy:
	lea (%rdx,%rcx,4),%rdx
	jmp .L_fixup_handle_tail
.L_fixup_1b_copy:
	movl %ecx,%edx
.L_fixup_handle_tail:
	sfence
	jmp .Lcopy_user_handle_tail
	.previous

	_ASM_EXTABLE_UA(1b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(2b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(3b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(4b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(5b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(6b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(7b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(8b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(9b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(10b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(11b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(12b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(13b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(14b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(15b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(16b, .L_fixup_4x8b_copy)
	_ASM_EXTABLE_UA(20b, .L_fixup_8b_copy)
	_ASM_EXTABLE_UA(21b, .L_fixup_8b_copy)
	_ASM_EXTABLE_UA(30b, .L_fixup_4b_copy)
	_ASM_EXTABLE_UA(31b, .L_fixup_4b_copy)
	_ASM_EXTABLE_UA(40b, .L_fixup_1b_copy)
	_ASM_EXTABLE_UA(41b, .L_fixup_1b_copy)
SYM_FUNC_END(__shadow_cp)
EXPORT_SYMBOL(__shadow_cp)
