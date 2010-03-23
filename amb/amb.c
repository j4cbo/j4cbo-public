/* amb.c
 *
 * Copyright (c) 2010 Jacob Potter
 *
 * McCarthy's "amb" operator, for continuation-passing-style C.
 *
 * Second half of the file: sample n-queens implementation.
 */

#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

jmp_buf * amb_stack;

__attribute__((noreturn)) void amb_fail() {
	if (!amb_stack) {
		fprintf(stderr, "-- amb failure --\n");
		exit(1);
	} else {
		longjmp(*amb_stack, 1);
	}
}

typedef void * (*amb_cont_t) (void * value, void * param);

void * amb(void * const * options, int n, amb_cont_t k, void * param) {
	/* If n = 0, try someone else. */
	if (n == 0) amb_fail();

	/* We have a new set of options; save them on * the stack. */
	volatile int position = -1;
	jmp_buf jb;
	jmp_buf * prev = amb_stack;
	amb_stack = &jb;

	setjmp(jb);

	/* Move on to the next option. If this is our first run
	 * through, position was previously -1, so it becomes 0. */
	if (++position == n) {
		/* We're out of options to try. */
		amb_stack = prev;
		amb_fail();
	}

	return k(options[position], param);
}

/************************************************************************/

#define P(x)	((void *)(x))
#define I(x)	((int)(x))

void * coords[] = {
	P(1), P(2), P(3), P(4), P(5), P(6), P(7), P(8)
};

#define NUM_COORDS	(sizeof(coords) / sizeof(coords[0]))

/* We define positions as an array of (row, col), (row, col), ... */ 

#define NUM_PIECES	8
int positions[NUM_PIECES * 2];

#define ROW(i)	(positions[i*2])
#define COL(i)	(positions[i*2+1])

void * assignPiece(void * input, void * param) {
	int numLeft = I(param);

	numLeft--;
	positions[numLeft] = I(input);

	/* Check that no two pieces are in the same row, column, or
	 * diagonal. If numLeft is odd, then we haven't picked both the
	 * x and the y for this piece, so don't bother checking. */
	int i, j;
	if (numLeft % 2 == 0) {
		for (i = numLeft / 2; i < NUM_PIECES - 1; i++) {
			for (j = i + 1; j < NUM_PIECES; j++) {
				if (   ROW(i) == ROW(j)
				    || COL(i) == COL(j)
				    || ROW(i) + COL(i) == ROW(j) + COL(j)
				    || ROW(i) - COL(i) == ROW(j) - COL(j))
					amb_fail();
			}
		}
	}

	/* If the whole board isn't filled in, add another piece. */
	if (numLeft > 0) {
		return amb(coords, NUM_COORDS, assignPiece, P(numLeft));
	}

	for (i = 0; i < NUM_PIECES; i++) {
		printf("(%d, %d)\n", ROW(i), COL(i));
	}
}

int main() {
	int i;
	for (i = 0; i < NUM_PIECES * 2; i++) positions[i] = -1;

	amb(coords, NUM_COORDS, assignPiece, P(NUM_PIECES * 2));
}
