# Keen 4 title fizzle, as keen4_boot_a recorded it (TIME-G4, open)

omnispeak's CK_FizzleFade: a 320-entry column table shuffled with rand(), each row y starting at
table position columns1[y] from iteration y, revealing the next two entries per iteration.

What the recording (keen4_boot_a, identical in keen4_boot_b) shows:
- The structure holds: one shuffled 320-entry table, walked forward two entries per row per iteration,
  row y beginning at iteration y (row 0 changes every iteration and serves as the clock).
- The table, as a cycle (the rotation is not fixed by the data), forward order:
  185, 266, 139, 173, 137, 105, 149, 186, 24, 73, 71, 116, 200, 284, 287, 223, 182, 164, 193, 130, 90, 317, 126, 136, 82, 274, 195, 122, 265, 199, 261, 206, 227, 224, 183, 177, 92, 301, 22, 256, 140, 310, 314, 2, 235, 297, 33, 194, 157, 40, 58, 96, 181, 273, 161, 46, 215, 9, 217, 5, 67, 249, 1, 255, 250, 25, 213, 312, 32, 180, 81, 120, 129, 187, 166, 56, 169, 232, 207, 50, 189, 41, 240, 6, 34, 64, 316, 103, 29, 242, 54, 197, 10, 132, 8, 280, 78, 309, 113, 158, 264, 239, 208, 293, 306, 69, 222, 16, 153, 246, 285, 27, 74, 226, 291, 167, 178, 7, 12, 205, 241, 171, 31, 21, 121, 219, 318, 295, 110, 260, 257, 101, 44, 294, 114, 281, 168, 176, 251, 48, 191, 135, 221, 47, 76, 156, 271, 277, 238, 184, 109, 165, 209, 304, 279, 289, 172, 313, 17, 218, 77, 299, 127, 52, 229, 204, 163, 203, 115, 150, 214, 26, 230, 53, 107, 243, 142, 247, 268, 123, 311, 210, 190, 253, 89, 236, 55, 231, 259, 201, 188, 97, 65, 272, 286, 237, 75, 292, 319, 15, 305, 298, 119, 288, 112, 91, 61, 131, 315, 145, 59, 14, 45, 263, 170, 148, 234, 118, 98, 198, 18, 296, 111, 159, 11, 282, 283, 108, 228, 38, 254, 102, 258, 49, 303, 60, 85, 160, 162, 13, 155, 66, 276, 57, 88, 104, 80, 95, 37, 100, 179, 216, 51, 68, 220, 28, 290, 308, 79, 39, 19, 267, 244, 270, 151, 93, 212, 43, 147, 225, 35, 134, 0, 302, 144, 154, 138, 307, 106, 83, 62, 128, 174, 23, 202, 278, 192, 4, 252, 63, 196, 124, 42, 269, 248, 94, 300, 262, 30, 72, 133, 175, 125, 87, 70, 211, 141, 99, 275, 143, 86, 152, 3, 36, 146, 20, 233, 117, 245, 84
- Row start positions are not columns1[y] for any rotation (residuals of several pairs, no pattern):
  probably a second random draw.
- Generators excluded for the table: Borland rand() from seed 1 with 0-3000 earlier calls, Borland rand()
  after srand(n) for every 16-bit n (0-3 earlier calls), Microsoft rand(), US_RndT from any index;
  index formulas (320*r)/0x8000, 16-bit overflow (signed and unsigned), r % 320.

Scripts: the session's scratchpad fizzle*.py (per-pixel reveal frames from the recording, the pair
chaining, the generator searches).
