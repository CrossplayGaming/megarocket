/*
===============================================================================

TILINF2C.C -- a TILEINFO to C converter program for Keen 1-3, by K1n9_Duk3
(written 2025-09-13, modified 2025-12-29 to rename tile attributes)

Feel free to do whatever you want with this code, but please give credit where
credit is due.

===============================================================================
*/

#include <stdio.h>
#include <conio.h>

char *blocknames[] =
{
	"nexttile",
	"intile",
	"northwall",
	"eastwall",
	"southwall",
	"westwall"
};
#define NUMBLOCKS (sizeof(blocknames)/sizeof(blocknames[0]))

#define TILES_PER_ROW 13

int ReadInt16LE(FILE *in)
{
	unsigned char buffer[2];
	int i;
	
	fread(buffer, 2, 1, in);
	
	i = buffer[0];
	i += buffer[1] * 256;
	
	// the following code is not neccessary when compiling a 16-bit executable
	// for DOS, but it might be useful when porting the code to other platforms:
	if (buffer[1] & 0x80)
	{
		// number is negative:
		i = ((unsigned int)i) - 0x10000;
	}
	
	return i;
}

void WriteBlock(FILE *in, FILE *out, char *name, unsigned numtiles)
{
	int n;
	unsigned rowstart;
	
	fprintf(out, "int %s[%u] =\n{\n\t", name, numtiles);
	rowstart = n = 0;
	while (numtiles--)
	{
		if (n == TILES_PER_ROW)
		{
			fprintf(out, ",\t// tiles %3u to %3u\n\t%2i", rowstart, rowstart+(TILES_PER_ROW-1), ReadInt16LE(in));
			n = 1;
			rowstart += TILES_PER_ROW;
		}
		else if (n)
		{
			fprintf(out, ",%2i", ReadInt16LE(in));
			n++;
		}
		else
		{
			fprintf(out, "%2i", ReadInt16LE(in));
			n++;
		}
	}
	fprintf(out, " \t// tiles %3u to %3u\n};\n\n", rowstart, rowstart+n-1);
}

int main(int argc, char **argv)
{
	FILE *in, *out;
	unsigned long size;
	unsigned numtiles, i;
	
	printf("TILINF2C - a TILEINFO to C converter program for Keen 1-3\n\n");
	if (argc != 3)
	{
		printf(
			"Usage:   tilinf2c <datafile> <cfile>\n\n"
			"Example: tilinf2c tileinfo.ck1 tinfck1.c\n\n");
		return 1;
	}
	
	printf("Opening %s ...", argv[1]);
	in = fopen(argv[1], "rb");
	if (!in)
	{
		printf(" ERROR!\n");
		return 2;
	}
	printf(" ok.\n");
	
	//
	// get size of input file
	//
	fseek(in, 0, SEEK_END);
	size = ftell(in);
	fseek(in, 0, SEEK_SET);
	printf("Size: %lu bytes\n", size);
	
	// the TILEINFO data consists of 6 blocks (anim, behavior, 4 walls), each
	// 2 bytes per tile, so the file *should* be a multiple of 12 bytes long:
	if (size % 12)
	{
		printf("ERROR: Size must be a multiple of 12 bytes!\n");
		fclose(in);
		return 2;
	}
	
	//
	// get number of tiles, warn if too many tiles
	//
	numtiles = size / 12;
	printf("Tiles: %u\n", numtiles);
	/*
	if (numtiles > 715)
	{
		printf("ERROR: Too many tiles (700 tiles max.)\n");
		fclose(in);
		return 2;
	}
	*/
	if (numtiles > 700)
	{
		printf("WARNING: Too many tiles (700 tiles max.)\n\n"
			"This warning is normal for Keen 3. The original KEEN3.EXE contains attribute\n"
			"data for 715 tiles, even though there are only 624 tiles in the tileset.\n"
			"You will be facing memory corruption if the tileset contains over 700 tiles!\n"
			"Be sure to adjust the MAXTILES constant in the assembly code if you really need\n"
			"to use more than 700 tiles in your mod.\n\nPress a key to continue.");
		while (kbhit()) getch();
		do getch(); while (kbhit());
		printf("\n");
	}
	
	// TODO: ask for confirmation if output file already exists!
	
	//
	// start writing the C output file
	//
	printf("Writing %s ...", argv[2]);
	out = fopen(argv[2], "wt");
	if (!out)
	{
		printf(" ERROR!\n");
		fclose(out);
		return 2;
	}
	printf(" ok.\n");
	
	fprintf(out,
		"//\n"
		"// TILE ATTRIBUTE DATA FOR KEEN 1-3 -- created by TILINF2C\n"
		"//\n"
		"// Input file was '%s'\n"
		"//\n\n", argv[1]);
	
	//
	// write the tile attribute blocks
	//
	printf("Writing attribute data...");
	for (i=0; i<NUMBLOCKS; i++)
	{
		WriteBlock(in, out, blocknames[i], numtiles);
		printf(".");
	}
	printf("done.\n");
	
	//
	// clean up and exit
	//
	fclose(out);
	fclose(in);
	
	return 0;
}