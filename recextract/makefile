CC=gcc
TARGET=recextract

all: $(TARGET)

$(TARGET):
	$(CC) -o $@ zlib-1.2.3\*.c recextract.c -Os -s
clean:
	rm -rf *o $(TARGET)
