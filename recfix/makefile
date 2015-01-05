CC=gcc
CFLAGS=-Os -s
TARGET=recfix

all: $(TARGET)

$(TARGET):
	$(CC) $(CFLAGS) -o $@ recfix.c
clean:
	rm -rf *o $(TARGET)
