/*
 * recfix v0.5 - fixes invalid header length in aoe2 recorded games
 *
 * Copyright (c) 2009-2013 biegleux <biegleux[at]gmail[dot]com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses>.
 */

#include <stdio.h>
#include <windows.h>

#define VERSION	"0.5"
#define MGL_EXT	"mgl"

FILE *fp = NULL;

void usage(char const *argv0) {
	fprintf(stdout,
		"Usage: %s filename\n"
		"\tfilename -- specifies the recorded game to fix\n"
		"%s fixes invalid header length in aoe2 recorded games\n"
		"%s v%s, copyright(c) 2009-2013 biegleux\n", argv0, argv0, argv0, VERSION);
	exit(EXIT_SUCCESS);
}

void halt(char *msg) {
	fprintf(stderr, msg);
	if (fp != NULL) {
		fclose(fp);
	}
	exit(EXIT_FAILURE);
}

int main(int argc, char *argv[]) {
	int is_mgl = 0;
	unsigned int *header_len, *value;
	char *buff = NULL;
	long file_size = 0, pos = 0;
	char *p;
	HANDLE hFile = NULL;
	FILETIME ftWrite = {0, 0};

	char *filename = argv[1];

	/* Check the validity of the command line */
	if (filename == NULL) {
		usage(argv[0]);
	}

	char *dot = strrchr(filename, '.');
	is_mgl = dot != NULL && !stricmp(dot + 1, MGL_EXT);

	if ((hFile = CreateFile(filename, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
			FILE_ATTRIBUTE_NORMAL, NULL)) != INVALID_HANDLE_VALUE) {
		GetFileTime(hFile, NULL, NULL, &ftWrite);
		CloseHandle(hFile);
	}

	/* open the input file */
	if ((fp = fopen(filename, "rb+")) == NULL) {
		halt("Error opening file\n");
	}

	/* get the file size */
	fseek(fp, 0, SEEK_END);
	file_size = ftell(fp);
	rewind(fp);

	/* allocate buffer for the file */
	if ((buff = (char*) malloc(sizeof(char) * file_size)) == NULL) {
		halt("Failed to allocate the memory\n");
	}

	/* copy the file into the buffer */
	if (fread(buff, sizeof(char), file_size, fp) != file_size) {
		halt("Error reading file\n");
	}

	/* read header_len information */
	if (file_size < sizeof(*header_len)) {
		halt("Error reading header_len bytes\n");
	}

	header_len = (unsigned int*) buff;

	/* check the header_len value */
	if (*header_len != 0) {
		halt("File seems to be OK (header_len is not zero)\n");
	}

	p = buff;
	while (pos <= file_size - 8) {
		value = (unsigned int*) p;
		if (*value == 0x01F4) {
			value++;
			if (*value == 0 || *value == 1) {
				*header_len = pos;
				break;
			}
		}
		p++;
		pos++;
	}

	if (*header_len == 0) {
		halt("Unable to find the valid header length\n");
	}

	*header_len -= (is_mgl ? 0 : 4);
	fprintf(stdout, "Header length found (%x), writing to the file...\n", *header_len);
	rewind(fp);

	if (fwrite(header_len, sizeof(*header_len), 1, fp) != 1) {
		halt("Unable to write file\n");
	}

	fclose(fp);

	if ((hFile = CreateFile(filename, GENERIC_WRITE, 0, NULL, OPEN_EXISTING,
			FILE_ATTRIBUTE_NORMAL, NULL)) != INVALID_HANDLE_VALUE) {
		if (ftWrite.dwLowDateTime != 0 && ftWrite.dwHighDateTime != 0)
			SetFileTime(hFile, NULL, NULL, &ftWrite);
		CloseHandle(hFile);
	}

	fprintf(stdout, "Done!\n");
	return EXIT_SUCCESS;
}
