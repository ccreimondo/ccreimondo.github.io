---
layout: post
title:  "Data Structures"
date:   2014-12-3 13:33:11
categories: notes ds
---

## Primitive Variables
Single variable & pointer.


## Arrays
A list with a fixed length.

### Advantages
- A perfect data structure to hold the individual values.
- Values can be accessed  randomly by index.

### Weakness
- Size fixed.


## Linked List
A linked list is a data structure that can hold an arbitrary number of data items, and can easily change size to add or remove items.

### Advantages
- Dynamic change.
- Be good at storing data when the number of items is either unknown, or subject to change.

### Weakness
- No way to access an arbitrary item, only traversing through every node.


## Queue
First In First Out (FIFO)

### Methods
- enqueue
- dequeue

### Cases
- Breadth-First Search (BFS)


## Stack
Last In First Out (LIFO)

### Cases
- Depth-First Search (DFS)


## Tree
Tree is a data structure consisting of one or more data nodes.


## Binary Tree
A special type of tree is a binary tree \- each node has, at most, two children.

### Advantages
- One of the most efficient ways to store and read a set of records that can be indexed by a key value in some way.
- Be preferable to an array of values that has been sorted \- adding an arbitrary item to a sorted array requires some time-consuming reorganization of the existing data in order to maintain the desired ordering.


## Priority Queue
Simply put, a priority queue accepts states, and internally stores them in a method such that it can quickly pull out the state that has the least cost.


## Hash Table
A set of keys each has an associated value. The key is used as an index to locate the associated values.Hashing is the process of generating a key value (in this case, typically a 32 or 64 bit integer) from a piece of data. This hash value then becomes a basis for organizing and sorting the data.

### Advantages
- The hash value becomes a basis for organizing and sorting the data.
- Different "hash buckets" can be set up to store data and sometimes make the search even faster.

### Weakness
- Need a good method to make hash.


## References
- [topcoder](http://community.topcoder.com/tc?module=Static&d1=tutorials&d2=dataStructures)
