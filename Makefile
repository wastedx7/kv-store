
# ==========================================
# Key-Value Store - Makefile
# ==========================================

# Compiler
CC = gcc

# Directories
SRC_DIR = src
INC_DIR = include
BUILD_DIR = build
TEST_DIR = tests

# Executable name
TARGET = kv-store

# Compiler flags
CFLAGS = -Wall -Wextra -Wpedantic -std=c11 -I$(INC_DIR)
DEBUG_FLAGS = -g -O0
RELEASE_FLAGS = -O2 -DNDEBUG

# Linker flags
LDFLAGS =

# Source files
SRCS = $(wildcard $(SRC_DIR)/*.c)

# Object files
OBJS = $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(SRCS))

# Default target
all: $(TARGET)

# Build executable
$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)

# Compile source files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Debug build
debug: CFLAGS += $(DEBUG_FLAGS)
debug: clean $(TARGET)

# Optimized release build
release: CFLAGS += $(RELEASE_FLAGS)
release: clean $(TARGET)

# Run the application
run: $(TARGET)
	./$(TARGET)

# Run with Valgrind
valgrind: $(TARGET)
	valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes ./$(TARGET)

# Run with AddressSanitizer and UndefinedBehaviorSanitizer
sanitize: CFLAGS += -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer
sanitize: LDFLAGS += -fsanitize=address,undefined
sanitize: clean $(TARGET)

# Compile and run a test file
# Usage: make test TEST=tests/test_hash_table.c
test:
	@test -n "$(TEST)" || (echo "Usage: make test TEST=tests/test_file.c"; exit 1)
	$(CC) $(CFLAGS) $(DEBUG_FLAGS) $(TEST) $(filter-out $(BUILD_DIR)/main.o,$(OBJS)) -o $(BUILD_DIR)/test_runner $(LDFLAGS)
	./$(BUILD_DIR)/test_runner

# Remove generated files
clean:
	rm -rf $(BUILD_DIR) $(TARGET)

# Rebuild from scratch
rebuild: clean all

# Declare targets that are not files
.PHONY: all debug release run valgrind sanitize test clean rebuild
