/*
 * recextract v0.1 - extracts the header section from the aoc recorded games
 *
 * Copyright (c) 2009, biegleux <biegleux[at]gmail[dot]com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses>.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "recextract.h"
#include "zlib-1.2.3/zlib.h"

void usage(char const *argv0)
{
	fprintf(stdout,
			"Usage: %s -f filename | -h\n"
			"\t-f filename -- input recorded game\n"
			"\t-h -- prints this text\n\n"
			"%s extracts the header section from the aoc recorded games\n"
			"%s v%s, copyright(c) 2009 biegleux\n", argv0, argv0, argv0, VERSION);
	exit(EXIT_SUCCESS);
}

int main(int argc, char *argv[])
{
	int c, code;
	char *filename = NULL;
	unsigned int header_len = 0;
	FILE *fin, *fout;
	char *buf = NULL;
	long file_size = 0;
	unsigned int max_len = 0;
	unsigned have;
	z_stream strm;
	char out[CHUNK];

	while ((c = getopt(argc, argv, "f:h")) != -1)
	{
		switch (c)
		{
			case 'f':
				filename = optarg;
				break;
			case 'h':
			case '?':
			default:
				usage(argv[0]);
				break;
		}
	}

	/* Check the validity of the command line */
	if (filename == NULL)
	{
		usage(argv[0]);
	}

	/* Open the input file */
	if ((fin = fopen(filename, "rb")) == NULL)
	{
		fprintf(stderr, "Error opening file\n");
		printf("%s", filename);
		return EXIT_FAILURE;
	}

	/* Get the file size */
	fseek(fin, 0, SEEK_END);
	file_size = ftell(fin);
	rewind(fin);

	/* Read header_len information */
	if (fread(&header_len, sizeof(header_len), 1, fin) != 1)
	{
		fprintf(stderr, "Error reading header_len bytes\n");
		fclose(fin);
		return EXIT_FAILURE;
	}

	/* Check the header_len value */
	if (header_len == 0)
	{
		fprintf(stderr, "Error: header_len is zero\n");
		fclose(fin);
		return EXIT_FAILURE;
	}

	/* Skip next_pos */
	fseek(fin, 4, SEEK_CUR);

	max_len = MIN(MAX_HEADER_LEN + 1, file_size - 8);

	/* Allocate buffer for the compressed header stream */
	if ((buf = (char*)malloc(sizeof(char)*max_len)) == NULL)
	{
		fprintf(stderr, "Failed to allocate the memory\n");
		fclose(fin);
		return EXIT_FAILURE;
	}

	/* Read the compressed header stream */
	if (fread(buf, 1, max_len, fin) != max_len)
	{
		fprintf(stderr, "Error reading header stream\n");
		fclose(fin);
		return EXIT_FAILURE;
	}

	char hdr_filename[strlen(filename) + strlen(".header")];
	sprintf(hdr_filename, "%s.header", filename);

	/* Create file for header data */
	if ((fout = fopen(hdr_filename, "wb+")) == NULL)
	{
		fprintf(stderr, "Error opening file\n");
		return EXIT_FAILURE;
	}

	/* Allocate inflate state */
	strm.zalloc = (alloc_func)Z_NULL;
	strm.zfree = (free_func)Z_NULL;
	strm.opaque = (voidpf)Z_NULL;

	strm.next_in = buf;
	strm.avail_in = header_len;

	/* Decompress header data */
	if ((code = inflateInit2(&strm, -MAX_WBITS) != Z_OK))
	{
		fprintf(stderr, "Error initializing stream for decompression\n");
		fclose(fin);
		fclose(fout);
		free(buf);
		return EXIT_FAILURE;
	}

	do
	{
		strm.avail_out = CHUNK;
		strm.next_out = out;
		if ((code = inflate(&strm, Z_NO_FLUSH)) == Z_STREAM_ERROR);
		{
			break;
		}
		switch (code)
		{
			case Z_NEED_DICT:
				code = Z_DATA_ERROR;
			case Z_DATA_ERROR:
			case Z_MEM_ERROR:
				(void)inflateEnd(&strm);
				break;
		}
		if (code != Z_OK && code != Z_STREAM_END)
		{
			break;
		}
		have = CHUNK - strm.avail_out;
		if (fwrite(out, 1, have, fout) != have || ferror(fout))
		{
			(void)inflateEnd(&strm);
			fprintf(stderr, "Error writing uncompressed stream\n");
			fclose(fin);
			fclose(fout);
			free(buf);
			return EXIT_FAILURE;
		}
	} while (strm.avail_out == 0);

	/* Clean up and return */
	fclose(fin);
	fclose(fout);
	free(buf);

	if (code != Z_OK && code != Z_STREAM_END)
	{
		fprintf(stderr, "Error decompressing stream\n");
		return EXIT_FAILURE;
	}

    (void)inflateEnd(&strm);

    return EXIT_SUCCESS;
}
