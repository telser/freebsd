/*-
 * Copyright (c) 2015 Ruslan Bukin <br@bsdpad.com>
 * All rights reserved.
 *
 * Portions of this software were developed by SRI International and the
 * University of Cambridge Computer Laboratory under DARPA/AFRL contract
 * FA8750-10-C-0237 ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * Portions of this software were developed by the University of Cambridge
 * Computer Laboratory as part of the CTSRD Project, with support from the
 * UK Higher Education Innovation Fund (HEIF).
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD$
 */

#include "assym.s"

#include <sys/syscall.h>
#include <machine/asm.h>
#include <machine/param.h>
#include <machine/trap.h>
#include <machine/riscvreg.h>
#include <machine/pte.h>

#define	HTIF_RING_SIZE	(64)
#define	HTIF_RING_LAST	(24 * (HTIF_RING_SIZE - 1))

	.globl	kernbase
	.set	kernbase, KERNBASE

	/* Trap entries */
	.text

mentry:
	/* User mode entry point (mtvec + 0x000) */
	.align 6
	j	user_trap

	/* Supervisor mode entry point (mtvec + 0x040) */
	.align 6
	j	supervisor_trap

	/* Hypervisor mode entry point (mtvec + 0x080) */
	.align 6
	j	bad_trap

	/* Machine mode entry point (mtvec + 0x0C0) */
	.align 6
	j	bad_trap

	/* Reset vector */
	.text
	.align 8
	.globl _start
_start:
	li	s11, KERNBASE

	/* Build ring */
	la	t0, htif_ring
	li	t1, 0
	sd	t1, 0(t0)	/* zero data */
	sd	t1, 8(t0)	/* zero used */
	mv	t2, t0
	mv	t3, t0
	li	t5, HTIF_RING_LAST
	li	t6, 0
	add	t4, t0, t5
1:
	addi	t3, t3, 24	/* pointer to next */
	beq	t3, t4, 2f	/* finish */
	sd	t3, 16(t2)	/* store pointer */
	addi	t2, t2, 24	/* next entry */
	addi	t6, t6, 1	/* counter */
	j	1b
2:
	sd	t0, 16(t3)	/* last -> first */
	la	t1, htif_ring_cursor
	sd	t0, 0(t1)
	la	t1, htif_ring_last
	sd	t0, 0(t1)
	/* finish building ring */

	la	t0, hardstack_end
	sub	t0, t0, s11
	csrw	mscratch, t0

	la	t0, mentry
	csrw	mtvec, t0

	li	t0, 0
	csrw	sscratch, t0

	li	s10, PAGE_SIZE
	li	s9, (PAGE_SIZE * KSTACK_PAGES)

	/* Page tables */

	/* Level 0 */
	la	s1, pagetable_l0
	la	s2, pagetable_l1	/* Link to next level PN */
	srli	s2, s2, PAGE_SHIFT

	li	t4, (PTE_VALID | (PTE_TYPE_PTR << PTE_TYPE_S))
	slli	t5, s2, PTE_PPN0_S	/* (s2 << PTE_PPN0_S) */
	or	t6, t4, t5

	/* Store single level0 PTE entry to position */
	li	a5, 0x1ff
	li	a6, PTE_SIZE
	mulw	a5, a5, a6
	add	t0, s1, a5
	sd	t6, 0(t0)

	/* Level 1 */
	la	s1, pagetable_l1
	la	s2, pagetable_l2	/* Link to next level PN */
	srli	s2, s2, PAGE_SHIFT

	li	a5, KERNBASE
	srli	a5, a5, 0x1e		/* >> 30 */
	andi	a5, a5, 0x1ff		/* & 0x1ff */
	li	t4, (PTE_VALID | (PTE_TYPE_PTR << PTE_TYPE_S))
	slli	t5, s2, PTE_PPN0_S	/* (s2 << PTE_PPN0_S) */
	or	t6, t4, t5

	/* Store single level1 PTE entry to position */
	li	a6, PTE_SIZE
	mulw	a5, a5, a6
	add	t0, s1, a5
	sd	t6, (t0)

	/* Level 2 superpages (512 x 2MiB) */
	la	s1, pagetable_l2
	li	t3, 512			/* Build 512 entries */
	li	t4, 0			/* Counter */
	li	t5, 0
2:
	li	t0, (PTE_VALID | (PTE_TYPE_SRWX << PTE_TYPE_S))
	slli	t2, t4, PTE_PPN1_S	/* << PTE_PPN1_S */
	or	t5, t0, t2
	sd	t5, (s1)		/* Store PTE entry to position */
	addi	s1, s1, PTE_SIZE

	addi	t4, t4, 1
	bltu	t4, t3, 2b

	/* Set page tables base register */
	la	s1, pagetable_l0
	csrw	sptbr, s1

	/* Page tables END */

	/* Enter supervisor mode */
	li	s0, ((MSTATUS_VM_SV48 << MSTATUS_VM_SHIFT) | \
		     (MSTATUS_PRV_M << MSTATUS_PRV_SHIFT) | \
		     (MSTATUS_PRV_S << MSTATUS_PRV1_SHIFT) | \
		     (MSTATUS_PRV_U << MSTATUS_PRV2_SHIFT));
	csrw	mstatus, s0

	/* Exit from machine mode */
	la	t0, .Lmmu_on
	add	t0, t0, s11
	csrw	mepc, t0
	eret

.Lmmu_on:
	/* Initialize stack pointer */
	la	s3, initstack_end
	mv	sp, s3
	addi	sp, sp, -PCB_SIZE

	/* Clear BSS  */
	la	a0, _C_LABEL(__bss_start)
	la	s1, _C_LABEL(_end)
1:
	sd	zero, 0(a0)
	addi	a0, a0, 8
	bltu	a0, s1, 1b

	/* Fill riscv_bootparams */
	addi	sp, sp, -16
	la	t0, pagetable_l1
	sd	t0, 0(sp) /* kern_l1pt */
	la	t0, initstack_end
	sd	t0, 8(sp) /* kern_stack */

	mv	a0, sp
	call	_C_LABEL(initriscv)	/* Off we go */
	call	_C_LABEL(mi_startup)

	.align  4
initstack:
	.space  (PAGE_SIZE * KSTACK_PAGES)
initstack_end:
hardstack:
	.space  (PAGE_SIZE)
hardstack_end:

	.globl htif_ring
htif_ring:
	.space  (24 * 1024)

	.globl htif_ring_cursor
htif_ring_cursor:
	.space  (8)

	.globl htif_ring_last
htif_ring_last:
	.space  (8)

	.globl console_intr
console_intr:
	.space  (8)

ENTRY(sigcode)
	mv	a0, sp
	addi	a0, a0, SF_UC

1:
	li	t0, SYS_sigreturn
	ecall

	/* sigreturn failed, exit */
	li	t0, SYS_exit
	ecall

	j	1b
END(sigcode)
	/* This may be copied to the stack, keep it 16-byte aligned */
	.align	3
esigcode:

	.data
	.align	3
	.global	szsigcode
szsigcode:
	.quad	esigcode - sigcode

	.align	12
	.globl pagetable_l0
pagetable_l0:
	.space	PAGE_SIZE
pagetable_l1:
	.space	PAGE_SIZE
pagetable_l2:
	.space	PAGE_SIZE
pagetable_end:

	.globl init_pt_va
init_pt_va:
	.quad pagetable_l2	/* XXX: Keep page tables VA */

#include "exception.S"
