#ifndef HASHTABLE_H
#define HASHTABLE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// structure for a single hash table entry
typedef struct {
    char* key;
    uint32_t key_len;
    void* val;
    uint32_t val_len;
    bool is_occupied;
    bool is_tombstone;
} kv_entry_t;

// structure for a single hash table generation
typedef struct {
    kv_entry_t* entries;
    size_t capacity;
    size_t size;
} kv_ht_t;

kv_ht_t* ht_create(size_t capacity); // function to create a hashtable
bool ht_set(kv_ht_t* ht, const char* key, uint32_t key_len, const void* val, uint32_t val_len); // set a value in the hash table
void* ht_get(kv_ht_t* ht, const char* key, uint32_t key_len, uint32_t out_val_len); // retrive a value in the hashtable
void ht_destroy(kv_ht_t* ht); // destroy the entire table

#endif