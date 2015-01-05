CC=gcc
CFLAGS=-Os -s -Wall
TARGET=recfix

all: $(TARGET)

$(TARGET):
	$(CC) $(CFLAGS) -o $@ recfix.c
clean:
	rm -rf *o $(TARGET)
