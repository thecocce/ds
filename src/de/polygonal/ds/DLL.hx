﻿/*
Copyright (c) 2008-2014 Michael Baczynski, http://www.polygonal.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package de.polygonal.ds;

import de.polygonal.ds.error.Assert.assert;

/**
 * <p>A doubly linked list.</p>
 * <p>See <a href="http://lab.polygonal.de/?p=206" target="mBlank">http://lab.polygonal.de/?p=206</a></p>
 * <p><o>Worst-case running time in Big O notation</o></p>
 */
#if (flash && generic)
@:generic
#end
@:access(de.polygonal.ds.DLLNode)
class DLL<T> implements Collection<T>
{
	/**
	 * A unique identifier for this object.<br/>
	 * A hash table transforms this key into an index of an array element by using a hash function.<br/>
	 * <warn>This value should never be changed by the user.</warn>
	 */
	public var key:Int;
	
	/**
	 * The head of this list or null if this list is empty.
	 */
	public var head(default, null):DLLNode<T>;
	
	/**
	 * The tail of this list or null if this list is empty.
	 */
	public var tail(default, null):DLLNode<T>;
	
	/**
	 * The maximum allowed size of this list.<br/>
	 * Once the maximum size is reached, adding an element will fail with an error (debug only).<br/>
	 * A value of -1 indicates that the size is unbound.<br/>
	 * <warn>Always equals -1 in release mode.</warn>
	 */
	public var maxSize:Int;
	
	/**
	 * If true, reuses the iterator object instead of allocating a new one when calling <code>iterator()</code>.<br/>
	 * The default is false.<br/>
	 * <warn>If true, nested iterations are likely to fail as only one iteration is allowed at a time.</warn>
	 */
	public var reuseIterator:Bool;
	
	var mSize:Int;
	var mReservedSize:Int;
	var mPoolSize:Int;
	
	var mHeadPool:DLLNode<T>;
	var mTailPool:DLLNode<T>;
	
	var mCircular:Bool;
	var mIterator:Itr<T>;
	
	/**
	 * @param reservedSize if &gt; 0, this list maintains an object pool of node objects.<br/>
	 * Prevents frequent node allocation and thus increases performance at the cost of using more memory.
	 * @param maxSize the maximum allowed size of this list.<br/>
	 * The default value of -1 indicates that there is no upper limit.
	 * @throws de.polygonal.ds.error.AssertError reserved size is greater than allowed size (debug only).
	 */
	public function new(reservedSize = 0, maxSize = -1)
	{
		#if debug
		if (reservedSize > 0)
		{
			if (maxSize != -1)
				assert(reservedSize <= maxSize, "reserved size is greater than allowed size");
		}
		this.maxSize = (maxSize == -1) ? M.INT32_MAX : maxSize;
		#else
		this.maxSize = -1;
		#end
		
		mReservedSize = reservedSize;
		mSize = 0;
		mPoolSize = 0;
		mCircular = false;
		mIterator = null;
		
		if (reservedSize > 0)
		{
			mHeadPool = mTailPool = new DLLNode<T>(cast null, this);
		}
		
		head = tail = null;
		key = HashKey.next();
		reuseIterator = false;
	}
	
	/**
	 * Returns true if this list is circular.<br/>
	 * A list is circular if the tail points to the head and vice versa.
	 * <o>1</o>
	 */
	public function isCircular():Bool
	{
		return mCircular;
	}
	
	/**
	 * Makes this list circular by connecting the tail to the head and vice versa.<br/>
	 * Silently fails if this list is already closed.
	 * <o>1</o>
	 */
	public function close()
	{
		if (mCircular) return;
		mCircular = true;
		if (valid(head))
		{
			tail.next = head;
			head.prev = tail;
		}
	}
	
	/**
	 * Makes this list non-circular by disconnecting the tail from the head and vice versa.<br/>
	 * Silently fails if this list is already non-circular.
	 * <o>1</o>
	 */
	public function open()
	{
		if (!mCircular) return;
		mCircular = false;
		if (valid(head))
		{
			tail.next = null;
			head.prev = null;
		}
	}
	
	/**
	 * Creates and returns a new <code>DLLNode</code> object storing the value <code>x</code> and pointing to this list.
	 * <o>1</o>
	 */
	public function createNode(x:T):DLLNode<T>
	{
		return new DLLNode<T>(x, this);
	}
	
	/**
	 * Appends the element <code>x</code> to the tail of this list by creating a <em>DLLNode</em> object storing <code>x</code>.
	 * <o>1</o>
	 * @return the appended node storing <code>x</code>.
	 * @throws de.polygonal.ds.error.AssertError <em>size()</em> equals <em>maxSize</em> (debug only).
	 */
	public function append(x:T):DLLNode<T>
	{
		#if debug
		if (maxSize != -1)
			assert(size() < maxSize, 'size equals max size ($maxSize)');
		#end
		
		var node = getNode(x);
		if (valid(tail))
		{
			tail.next = node;
			node.prev = tail;
		}
		else
			head = node;
		tail = node;
		
		if (mCircular)
		{
			tail.next = head;
			head.prev = tail;
		}
		
		mSize++;
		return node;
	}
	
	/**
	 * Appends the node <code>x</code> to this list.
	 * <o>1</o>
	 */
	public function appendNode(x:DLLNode<T>)
	{
		#if debug
		assert(x.getList() == this, "node is not managed by this list");
		#end
		
		if (valid(tail))
		{
			tail.next = x;
			x.prev = tail;
		}
		else
			head = x;
		tail = x;
		
		if (mCircular)
		{
			tail.next = head;
			head.prev = tail;
		}
		
		mSize++;
	}
	
	/**
	 * Prepends the element <code>x</code> to the head of this list by creating a <em>DLLNode</em> object storing <code>x</code>.
	 * <o>1</o>
	 * @return the prepended node storing <code>x</code>.
	 * @throws de.polygonal.ds.error.AssertError <em>size()</em> equals <em>maxSize</em> (debug only).
	 */
	public function prepend(x:T):DLLNode<T>
	{
		#if debug
		if (maxSize != -1)
			assert(size() < maxSize, 'size equals max size ($maxSize)');
		#end
		
		var node = getNode(x);
		node.next = head;
		if (valid(head))
			head.prev = node;
		else
			tail = node;
		head = node;
		
		if (mCircular)
		{
			tail.next = head;
			head.prev = tail;
		}
		
		mSize++;
		return node;
	}
	
	/**
	 * Prepends the node <code>x</code> to this list.
	 * <o>1</o>
	 */
	public function prependNode(x:DLLNode<T>)
	{
		#if debug
		assert(x.getList() == this, "node is not managed by this list");
		#end
		
		x.next = head;
		if (valid(head))
			head.prev = x;
		else
			tail = x;
		head = x;
		
		if (mCircular)
		{
			tail.next = head;
			head.prev = tail;
		}
		
		mSize++;
	}
	
	/**
	 * Inserts the element <code>x</code> after <code>node</code> by creating a <em>DLLNode</em> object storing <code>x</code>.
	 * <o>1</o>
	 * @return the inserted node storing <code>x</code>.
	 * @throws de.polygonal.ds.error.AssertError <code>node</code> is null or not managed by this list (debug only).
	 */
	public function insertAfter(node:DLLNode<T>, x:T):DLLNode<T>
	{
		#if debug
		if (maxSize != -1)
			assert(size() < maxSize, 'size equals max size ($maxSize)');
		assert(valid(node), "node is null");
		assert(node.getList() == this, "node is not managed by this list");
		#end
		
		var t = getNode(x);
		node.insertAfter(t);
		if (node == tail)
		{
			tail = t;
			if (mCircular)
				tail.next = head;
		}
		
		mSize++;
		return t;
	}
	
	/**
	 * Inserts the element <code>x</code> before <code>node</code> by creating a <em>DLLNode</em> object storing <code>x</code>.
	 * <o>1</o>
	 * @return the inserted node storing <code>x</code>.
	 * @throws de.polygonal.ds.error.AssertError <code>node</code> is null or not managed by this list (debug only).
	 */
	public function insertBefore(node:DLLNode<T>, x:T):DLLNode<T>
	{
		#if debug
		if (maxSize != -1)
			assert(size() < maxSize, 'size equals max size ($maxSize)');
		assert(valid(node), "node is null");
		assert(node.getList() == this, "node is not managed by this list");
		#end
		
		var t = getNode(x);
		node.insertBefore(t);
		if (node == head)
		{
			head = t;
			if (mCircular)
				head.prev = tail;
		}
		
		mSize++;
		return t;
	}
	
	/**
	 * Unlinks <code>node</code> from this list and returns <code>node</code>.<em>next</em>;
	 * <o>1</o>
	 * @throws de.polygonal.ds.error.AssertError list is empty (debug only).
	 * @throws de.polygonal.ds.error.AssertError <code>node</code> is null or not managed by this list (debug only).
	 */
	public function unlink(node:DLLNode<T>):DLLNode<T>
	{
		#if debug
		assert(valid(node), "node is null");
		assert(node.getList() == this, "node is not managed by this list");
		assert(mSize > 0, "list is empty");
		#end
		
		var hook = node.next;
		if (node == head)
		{
			head = head.next;
			if (mCircular)
			{
				if (head == tail)
					head = null;
				else
					tail.next = head;
			}
			
			if (head == null) tail = null;
		}
		else
		if (node == tail)
		{
			tail = tail.prev;
			if (mCircular)
				head.prev = tail;
				
			if (tail == null) head = null;
		}
		
		node._unlink();
		putNode(node);
		mSize--;
		
		return hook;
	}
	
	/**
	 * Returns the node at "index" <code>i</code>.<br/>
	 * The index is measured relative to the head node (= index 0).
	 * <o>n</o>
	 * @throws de.polygonal.ds.error.AssertError list is empty (debug only).
	 * @throws de.polygonal.ds.error.AssertError index out of range (debug only).
	 */
	public function getNodeAt(i:Int):DLLNode<T>
	{
		#if debug
		assert(mSize > 0, "list is empty");
		assert(i >= 0 || i < mSize, 'i index out of range ($i)');
		#end
		
		var node = head;
		for (j in 0...i) node = node.next;
		return node;
	}
	
	/**
	 * Removes the head node and returns the element stored in this node.
	 * <o>n</o>
	 * @throws de.polygonal.ds.error.AssertError list is empty (debug only).
	 */
	public function removeHead():T
	{
		#if debug
		assert(mSize > 0, "list is empty");
		#end
		
		var node = head;
		if (head == tail)
			head = tail = null;
		else
		{
			head = head.next;
			node.next = null;
			
			if (mCircular)
			{
				head.prev = tail;
				tail.next = head;
			}
			else
				head.prev = null;
		}
		mSize--;
		
		return putNode(node);
	}
	
	/**
	 * Removes the tail node and returns the element stored in this node.
	 * <o>1</o>
	 * @throws de.polygonal.ds.error.AssertError list is empty (debug only).
	 */
	public function removeTail():T
	{
		#if debug
		assert(mSize > 0, "list is empty");
		#end
		
		var node = tail;
		if (head == tail)
			head = tail = null;
		else
		{
			tail = tail.prev;
			node.prev = null;
			
			if (mCircular)
			{
				tail.next = head;
				head.prev = tail;
			}
			else
				tail.next = null;
		}
		
		mSize--;
		
		return putNode(node);
	}
	
	/**
	 * Unlinks the head node and appends it to the tail.
	 * <o>1</o>
	 * @throws de.polygonal.ds.error.AssertError list is empty (debug only).
	 */
	public function shiftUp()
	{
		#if debug
		assert(mSize > 0, "list is empty");
		#end
		
		if (mSize > 1)
		{
			var t = head;
			if (head.next == tail)
			{
				head = tail;
				head.prev = null;
				
				tail = t;
				tail.next = null;
				
				head.next = tail;
				tail.prev = head;
			}
			else
			{
				head = head.next;
				head.prev = null;
				
				tail.next = t;
				
				t.next = null;
				t.prev = tail;
				
				tail = t;
			}
			
			if (mCircular)
			{
				tail.next = head;
				head.prev = tail;
			}
		}
	}
	
	/**
	 * Unlinks the tail node and prepends it to the head.
	 * <o>1</o>
	 * @throws de.polygonal.ds.error.AssertError list is empty (debug only).
	 */
	public function popDown()
	{
		#if debug
		assert(mSize > 0, "list is empty");
		#end
		
		if (mSize > 1)
		{
			var t = tail;
			if (tail.prev == head)
			{
				tail = head;
				tail.next = null;
				
				head = t;
				head.prev = null;
				
				head.next = tail;
				tail.prev = head;
			}
			else
			{
				tail = tail.prev;
				tail.next = null;
				
				head.prev = t;
				
				t.prev = null;
				t.next = head;
				
				head = t;
			}
			
			if (mCircular)
			{
				tail.next = head;
				head.prev = tail;
			}
		}
	}
	
	/**
	 * Searches for the element <code>x</code> in this list from head to tail starting at node <code>from</code>.
	 * <o>n</o>
	 * @return the node containing <code>x</code> or null if such a node does not exist.<br/>
	 * If <code>from</code> is null, the search starts at the head of this list.
	 * @throws de.polygonal.ds.error.AssertError <code>from</code> is not managed by this list (debug only).
	 */
	public function nodeOf(x:T, from:DLLNode<T> = null):DLLNode<T>
	{
		#if debug
		if (valid(from))
			assert(from.getList() == this, "node is not managed by this list");
		#end
		
		var node = (from == null) ? head : from;
		if (mCircular)
		{
			while (node != tail)
			{
				if (node.val == x) return node;
				node = node.next;
			}
			if (node.val == x) return node;
		}
		else
		{
			while (valid(node))
			{
				if (node.val == x) return node;
				node = node.next;
			}
		}
		return null;
	}
	
	/**
	 * Searches for the element <code>x</code> in this list from tail to head starting at node <code>from</code>.
	 * <o>n</o>
	 * @return the node containing <code>x</code> or null if such a node does not exist.<br/>
	 * If <code>from</code> is null, the search starts at the tail of this list.
	 * @throws de.polygonal.ds.error.AssertError <code>from</code> is not managed by this list (debug only).
	 */
	public function lastNodeOf(x:T, from:DLLNode<T> = null):DLLNode<T>
	{
		#if debug
		if (valid(from))
			assert(from.getList() == this, "node is not managed by this list");
		#end
		
		var node = (from == null) ? tail : from;
		if (mCircular)
		{
			while (node != head)
			{
				if (node.val == x) return node;
				node = node.prev;
			}
			if (node.val == x) return node;
		}
		else
		{
			while (valid(node))
			{
				if (node.val == x) return node;
				node = node.prev;
			}
		}
		return null;
	}
	
	/**
	 * Sorts the elements of this list using the merge sort algorithm.
	 * <o>n log n for merge sort and n&sup2; for insertion sort</o>
	 * @param compare a comparison function.<br/>
	 * If null, the elements are compared using element.<em>compare()</em>.<br/>
	 * <warn>In this case all elements have to implement <em>Comparable</em>.</warn>
	 * @param useInsertionSort if true, the linked list is sorted using the insertion sort algorithm.
	 * This is faster for nearly sorted lists.
	 * @throws de.polygonal.ds.error.AssertError element does not implement <em>Comparable</em> (debug only).
	 */
	public function sort(compare:T->T->Int, useInsertionSort = false)
	{
		if (mSize > 1)
		{
			if (mCircular)
			{
				tail.next = null;
				head.prev = null;
			}
			
			if (compare == null)
			{
				head = useInsertionSort ? insertionSortComparable(head) : mergeSortComparable(head);
			}
			else
			{
				head = useInsertionSort ? insertionSort(head, compare) : mergeSort(head, compare);
			}
			
			if (mCircular)
			{
				tail.next = head;
				head.prev = tail;
			}
		}
	}
	
	/**
	 * Merges this list with the list <code>x</code> by linking both lists together.<br/>
	 * <warn>The merge operation destroys x so it should be discarded.</warn>
	 * <o>n</o>
	 * @throws de.polygonal.ds.error.AssertError <code>x</code> is null or this list equals <code>x</code> (debug only).
	 */
	public function merge(x:DLL<T>)
	{
		#if debug
		if (maxSize != -1)
			assert(size() + x.size() <= maxSize, 'size equals max size ($maxSize)');
		assert(x != this, "x equals this list");
		assert(x != null, "x is null");
		#end
		
		if (valid(x.head))
		{
			var node = x.head;
			for (i in 0...x.size())
			{
				node.mList = this;
				node = node.next;
			}
				
			if (valid(head))
			{
				tail.next = x.head;
				x.head.prev = tail;
				tail = x.tail;
			}
			else
			{
				head = x.head;
				tail = x.tail;
			}
			
			mSize += x.size();
			
			if (mCircular)
			{
				tail.next = head;
				head.prev = tail;
			}
		}
	}
	
	/**
	 * Concatenates this list with the list <code>x</code> by appending all elements of <code>x</code> to this list.<br/>
	 * This list and <code>x</code> are untouched.
	 * <o>n</o>
	 * @return a new list containing the elements of both lists.
	 * @throws de.polygonal.ds.error.AssertError <code>x</code> is null or this equals <code>x</code> (debug only).
	 */
	public function concat(x:DLL<T>):DLL<T>
	{
		#if debug
		assert(x != null, "x is null");
		assert(x != this, "x equals this list");
		#end
		
		var c = new DLL<T>();
		var k = x.size();
		if (k > 0)
		{
			var node = x.tail;
			var t = c.tail = new DLLNode<T>(node.val, c);
			node = node.prev;
			var i = k - 1;
			while (i-- > 0)
			{
				var copy = new DLLNode<T>(node.val, c);
				copy.next = t;
				t.prev = copy;
				t = copy;
				node = node.prev;
			}
			
			c.head = t;
			c.mSize = k;
			
			if (mSize > 0)
			{
				var node = tail;
				var i = mSize;
				while (i-- > 0)
				{
					var copy = new DLLNode<T>(node.val, c);
					copy.next = t;
					t.prev = copy;
					t = copy;
					node = node.prev;
				}
				c.head = t;
				c.mSize += mSize;
			}
		}
		else
		if (mSize > 0)
		{
			var node = tail;
			var t = c.tail = new DLLNode<T>(node.val, this);
			node = node.prev;
			var i = mSize - 1;
			while (i-- > 0)
			{
				var copy = new DLLNode<T>(node.val, this);
				copy.next = t;
				t.prev = copy;
				t = copy;
				node = node.prev;
			}
			
			c.head = t;
			c.mSize = mSize;
		}
		
		return c;
	}
	
	/**
	 * Reverses the linked list in place.
	 * <o>n</o>
	 */
	public function reverse()
	{
		if (mSize <= 1)
			return;
		else
		if (mSize <= 3)
		{
			var t = head.val;
			head.val = tail.val;
			tail.val = t;
		}
		else
		{
			var head = head;
			var tail = tail;
			for (i in 0...mSize >> 1)
			{
				var t = head.val;
				head.val = tail.val;
				tail.val = t;
				
				head = head.next;
				tail = tail.prev;
			}
		}
	}
	
	/**
	 * Converts the data in the linked list to strings, inserts <code>x</code> between the elements, concatenates them, and returns the resulting string.
	 * <o>n</o>
	 */
	public function join(x:String):String
	{
		var s = "";
		if (mSize > 0)
		{
			var node = head;
			for (i in 0...mSize - 1)
			{
				s += Std.string(node.val) + x;
				node = node.next;
			}
			s += Std.string(node.val);
		}
		return s;
	}
	
	/**
	 * Replaces up to <code>n</code> existing elements with objects of type <code>C</code>.
	 * <o>n</o>
	 * @param C the class to instantiate for each element.
	 * @param args passes additional constructor arguments to <code>C</code>.
	 * @param n the number of elements to replace. If 0, <code>n</code> is set to <em>size()</em>.
	 * @throws de.polygonal.ds.error.AssertError <code>n</code> out of range (debug only).
	 */
	public function assign(C:Class<T>, args:Array<Dynamic> = null, n = 0)
	{
		#if debug
		assert(n >= 0, "n >= 0");
		#end
		
		if (n > 0)
		{
			#if debug
			if (maxSize != -1)
				assert(n <= size(), 'n out of range ($n)');
			#end
		}
		else
			n = size();
		
		if (args == null) args = [];
		var node = head;
		for (i in 0...n)
		{
			node.val = Type.createInstance(C, args);
			node = node.next;
		}
	}
	
	/**
	 * Replaces up to <code>n</code> existing elements with the instance of <code>x</code>.
	 * <o>n</o>
	 * @param n the number of elements to replace. If 0, <code>n</code> is set to <em>size()</em>.
	 * @throws de.polygonal.ds.error.AssertError <code>n</code> out of range (debug only).
	 */
	public function fill(x:T, args:Array<Dynamic> = null, n = 0):DLL<T>
	{
		#if debug
		assert(n >= 0, "n >= 0");
		#end
		
		if (n > 0)
		{
			#if debug
			if (maxSize != -1)
				assert(n <= size(), 'n out of range ($n)');
			#end
		}
		else
			n = size();
		
		var node = head;
		for (i in 0...n)
		{
			node.val = x;
			node = node.next;
		}
		
		return this;
	}
	
	/**
	 * Shuffles the elements of this collection by using the Fisher-Yates algorithm.<br/>
	 * <o>n</o>
	 * @param rval a list of random double values in the range between 0 (inclusive) to 1 (exclusive) defining the new positions of the elements.
	 * If omitted, random values are generated on-the-fly by calling <em>Math.random()</em>.
	 * @throws de.polygonal.ds.error.AssertError insufficient random values (debug only).
	 */
	public function shuffle(rval:Array<Float> = null)
	{
		var s = mSize;
		if (rval == null)
		{
			var m = Math;
			while (s > 1)
			{
				s--;
				var i = Std.int(m.random() * s);
				var node1 = head;
				for (j in 0...s) node1 = node1.next;
				
				var t = node1.val;
				
				var node2 = head;
				for (j in 0...i) node2 = node2.next;
				
				node1.val = node2.val;
				node2.val = t;
			}
		}
		else
		{
			#if debug
			assert(rval.length >= size(), "insufficient random values");
			#end
			
			var j = 0;
			while (s > 1)
			{
				s--;
				var i = Std.int(rval[j++] * s);
				var node1 = head;
				for (j in 0...s) node1 = node1.next;
				
				var t = node1.val;
				
				var node2 = head;
				for (j in 0...i) node2 = node2.next;
				
				node1.val = node2.val;
				node2.val = t;
			}
		}
		
		if (mCircular)
		{
			tail.next = head;
			head.prev = tail;
		}
	}
	
	/**
	 * Returns a string representing the current object.<br/>
	 * Example:<br/>
	 * <pre class="prettyprint">
	 * var dll = new de.polygonal.ds.DLL&lt;Int&gt;();
	 * for (i in 0...4) {
	 *     dll.append(i);
	 * }
	 * trace(dll);</pre>
	 * <pre class="console">
	 * { DLL size: 4, circular: false }
 	 * [ head
	 *   0
	 *   1
	 *   2
	 *   3
	 * ] tail</pre>
	 */
	public function toString():String
	{
		var s = '{ DLL size: ${size()}, circular: ${isCircular()} }';
		if (isEmpty()) return s;
		s += "\n[ head \n";
		var node = head;
		for (i in 0...mSize)
		{
			s += '  ${Std.string(node.val)}\n';
			node = node.next;
		}
		s += "] tail";
		return s;
	}
	
	/*///////////////////////////////////////////////////////
	// collection
	///////////////////////////////////////////////////////*/
	
	/**
	 * Destroys this object by explicitly nullifying all nodes, pointers and data for GC'ing used resources.<br/>
	 * Improves GC efficiency/performance (optional).
	 * <o>n</o>
	 */
	public function free()
	{
		var node = head;
		for (i in 0...mSize)
		{
			var next = node.next;
			node.free();
			node = next;
		}
		head = tail = null;
		
		var node = mHeadPool;
		while (valid(node))
		{
			var next = node.next;
			node.free();
			node = next;
		}
		
		mHeadPool = mTailPool = null;
		mIterator = null;
	}
	
	/**
	 * Returns true if this list contains a node storing the element <code>x</code>.
	 * <o>n</o>
	 */
	public function contains(x:T):Bool
	{
		var node = head;
		for (i in 0...mSize)
		{
			if (node.val == x)
				return true;
			node = node.next;
		}
		return false;
	}
	
	/**
	 * Removes all nodes storing the element <code>x</code>.
	 * <o>n</o>
	 * @return true if at least one occurrence of <code>x</code> was removed.
	 */
	public function remove(x:T):Bool
	{
		var s = size();
		if (s == 0) return false;
		
		var node = head;
		while (valid(node))
		{
			if (node.val == x)
				node = unlink(node);
			else
				node = node.next;
		}
		
		return size() < s;
	}
	
	/**
	 * Removes all elements.
	 * <o>1 or n if <code>purge</code> is true</o>
	 * @param purge if true, nodes, pointers and elements are nullified upon removal.
	 */
	public function clear(purge = false)
	{
		if (purge || mReservedSize > 0)
		{
			var node = head;
			for (i in 0...mSize)
			{
				var next = node.next;
				node.prev = null;
				node.next = null;
				putNode(node);
				node = next;
			}
		}
		
		head = tail = null;
		mSize = 0;
	}
	
	/**
	 * Returns a new <em>DLLIterator</em> object to iterate over all elements contained in this doubly linked list.<br/>
	 * Uses a <em>CircularDLLIterator</em> iterator object if <em>circular</em> is true.
	 * The elements are visited from head to tail.<br/>
	 * If performance is crucial, use the following loop instead:<br/><br/>
	 * <pre class="prettyprint">
	 * //open list:
	 * var node = myDLL.head;
	 * while (node != null)
	 * {
	 *     var element = node.val;
	 *     node = node.next;
	 * }
	 *
	 * //circular list:
	 * var node = myDLL.head;
	 * for (i in 0...list.size())
	 * {
	 *     var element = node.val;
	 *     node = node.next;
	 * }
	 * </pre>
	 * @see <a href="http://haxe.org/ref/iterators" target="mBlank">http://haxe.org/ref/iterators</a>
	 *
	 */
	public function iterator():Itr<T>
	{
		if (reuseIterator)
		{
			if (mIterator == null)
			{
				if (mCircular)
					return new CircularDLLIterator<T>(this);
				else
					return new DLLIterator<T>(this);
			}
			else
				mIterator.reset();
			return mIterator;
		}
		else
		{
			if (mCircular)
				return new CircularDLLIterator<T>(this);
			else
				return new DLLIterator<T>(this);
		}
	}
	
	/**
	 * The total number of elements.
	 * <o>1</o>
	 */
	inline public function size():Int
	{
		return mSize;
	}
	
	/**
	 * Returns true if this list is empty.
	 * <o>1</o>
	 */
	inline public function isEmpty():Bool
	{
		return mSize == 0;
	}
	
	/**
	 * Returns an array containing all elements in this doubly linked list.<br/>
	 * Preserves the natural order of this linked list.
	 */
	public function toArray():Array<T>
	{
		var a:Array<T> = ArrayUtil.alloc(size());
		var node = head;
		for (i in 0...mSize)
		{
			a[i] = node.val;
			node = node.next;
		}
		return a;
	}
	
	/**
	 * Returns a vector.&lt;T&gt; objec containing all elements in this doubly linked list.<br/>
	 * Preserves the natural order of this linked list.
	 */
	inline public function toVector():Vector<T>
	{
		var v = new Vector<T>(size());
		var node = head;
		for (i in 0...mSize)
		{
			v[i] = node.val;
			node = node.next;
		}
		return v;
	}
	
	/**
	 * Duplicates this linked list. Supports shallow (structure only) and deep copies (structure & elements).
	 * @param assign if true, the <code>copier</code> parameter is ignored and primitive elements are copied by value whereas objects are copied by reference.<br/>
	 * If false, the <em>clone()</em> method is called on each element. <warn>In this case all elements have to implement <em>Cloneable</em>.</warn>
	 * @param copier a custom function for copying elements. Replaces element.<em>clone()</em> if <code>assign</code> is false.
	 * @throws de.polygonal.ds.error.AssertError element is not of type <em>Cloneable</em> (debug only).
	 */
	public function clone(assign = true, copier:T->T = null):Collection<T>
	{
		if (mSize == 0)
		{
			var copy = new DLL<T>(mReservedSize, maxSize);
			if (mCircular) copy.mCircular = true;
			return copy;
		}
		
		var copy = new DLL<T>();
		copy.mSize = mSize;
		
		if (assign)
		{
			var srcNode = head;
			var dstNode = copy.head = new DLLNode<T>(head.val, copy);
			
			if (mSize == 1)
			{
				copy.tail = copy.head;
				if (mCircular) copy.tail.next = copy.head;
				return copy;
			}
			
			var dstNode0;
			srcNode = srcNode.next;
			for (i in 1...mSize - 1)
			{
				dstNode0 = dstNode;
				var srcNode0 = srcNode;
				
				dstNode = dstNode.next = new DLLNode<T>(srcNode.val, copy);
				dstNode.prev = dstNode0;
				
				srcNode0 = srcNode;
				srcNode = srcNode0.next;
			}
			
			dstNode0 = dstNode;
			copy.tail = dstNode.next = new DLLNode<T>(srcNode.val, copy);
			copy.tail.prev = dstNode0;
		}
		else
		if (copier == null)
		{
			var srcNode = head;
			
			#if debug
			assert(Std.is(head.val, Cloneable), 'element is not of type Cloneable (${head.val})');
			#end
			
			var c = cast(head.val, Cloneable<Dynamic>);
			var dstNode = copy.head = new DLLNode<T>(c.clone(), copy);
			if (mSize == 1)
			{
				copy.tail = copy.head;
				if (mCircular) copy.tail.next = copy.head;
				return copy;
			}
			
			var dstNode0;
			srcNode = srcNode.next;
			for (i in 1...mSize - 1)
			{
				dstNode0 = dstNode;
				var srcNode0 = srcNode;
				
				#if debug
				assert(Std.is(srcNode.val, Cloneable), 'element is not of type Cloneable (${srcNode.val})');
				#end
				
				c = cast(srcNode.val, Cloneable<Dynamic>);
				
				dstNode = dstNode.next = new DLLNode<T>(c.clone(), copy);
				dstNode.prev = dstNode0;
				
				srcNode0 = srcNode;
				srcNode = srcNode0.next;
			}
			
			#if debug
			assert(Std.is(srcNode.val, Cloneable), 'element is not of type Cloneable (${srcNode.val})');
			#end
			
			c = cast(srcNode.val, Cloneable<Dynamic>);
			dstNode0 = dstNode;
			copy.tail = dstNode.next = new DLLNode<T>(c.clone(), copy);
			copy.tail.prev = dstNode0;
		}
		else
		{
			var srcNode = head;
			var dstNode = copy.head = new DLLNode<T>(copier(head.val), copy);
			
			if (mSize == 1)
			{
				copy.tail = copy.head;
				if (mCircular) copy.tail.next = copy.head;
				return copy;
			}
			
			var dstNode0;
			srcNode = srcNode.next;
			for (i in 1...mSize - 1)
			{
				dstNode0 = dstNode;
				var srcNode0 = srcNode;
				
				dstNode = dstNode.next = new DLLNode<T>(copier(srcNode.val), copy);
				dstNode.prev = dstNode0;
				
				srcNode0 = srcNode;
				srcNode = srcNode0.next;
			}
			
			dstNode0 = dstNode;
			copy.tail = dstNode.next = new DLLNode<T>(copier(srcNode.val), copy);
			copy.tail.prev = dstNode0;
		}
		
		if (mCircular) copy.tail.next = copy.head;
		return copy;
	}
	
	function mergeSortComparable(node:DLLNode<T>):DLLNode<T>
	{
		var h = node;
		var p, q, e, tail = null;
		var insize = 1;
		var nmerges, psize, qsize, i;
		
		while (true)
		{
			p = h;
			h = tail = null;
			nmerges = 0;
			
			while (valid(p))
			{
				nmerges++;
				
				psize = 0; q = p;
				for (i in 0...insize)
				{
					psize++;
					q = q.next;
					if (q == null) break;
				}
				
				qsize = insize;
				
				while (psize > 0 || (qsize > 0 && valid(q)))
				{
					if (psize == 0)
					{
						e = q; q = q.next; qsize--;
					}
					else
					if (qsize == 0 || q == null)
					{
						e = p; p = p.next; psize--;
					}
					else
					{
						#if debug
						assert(Std.is(p.val, Comparable), 'element is not of type Comparable (${p.val})');
						#end
						
						if (cast(p.val, Comparable<Dynamic>).compare(q.val) >= 0)
						{
							e = p; p = p.next; psize--;
						}
						else
						{
							e = q; q = q.next; qsize--;
						}
					}
					
					if (valid(tail))
						tail.next = e;
					else
						h = e;
					
					e.prev = tail;
					tail = e;
				}
				p = q;
			}
			
			tail.next = null;
			if (nmerges <= 1) break;
			insize <<= 1;
		}
		
		h.prev = null;
		this.tail = tail;
		
		return h;
	}
	
	function mergeSort(node:DLLNode<T>, cmp:T->T->Int):DLLNode<T>
	{
		var h = node;
		var p, q, e, tail = null;
		var insize = 1;
		var nmerges, psize, qsize, i;
		
		while (true)
		{
			p = h;
			h = tail = null;
			nmerges = 0;
			
			while (valid(p))
			{
				nmerges++;
				
				psize = 0; q = p;
				for (i in 0...insize)
				{
					psize++;
					q = q.next;
					if (q == null) break;
				}
				
				qsize = insize;
				
				while (psize > 0 || (qsize > 0 && valid(q)))
				{
					if (psize == 0)
					{
						e = q; q = q.next; qsize--;
					}
					else
					if (qsize == 0 || q == null)
					{
						e = p; p = p.next; psize--;
					}
					else
					if (cmp(q.val, p.val) >= 0)
					{
						e = p; p = p.next; psize--;
					}
					else
					{
						e = q; q = q.next; qsize--;
					}
					
					if (valid(tail))
						tail.next = e;
					else
						h = e;
					
					e.prev = tail;
					tail = e;
				}
				p = q;
			}
			
			tail.next = null;
			if (nmerges <= 1) break;
			insize <<= 1;
		}
		
		h.prev = null;
		this.tail = tail;
		
		return h;
	}
	
	function insertionSortComparable(node:DLLNode<T>):DLLNode<T>
	{
		var h = node;
		var n = h.next;
		while (valid(n))
		{
			var m = n.next;
			var p = n.prev;
			var v = n.val;
			
			#if debug
			assert(Std.is(p.val, Comparable), 'element is not of type Comparable (${p.val})');
			#end
			
			if (cast(p.val, Comparable<Dynamic>).compare(v) < 0)
			{
				var i = p;
				
				while (i.hasPrev())
				{
					#if debug
					assert(Std.is(i.prev.val, Comparable), 'element is not of type Comparable (${i.prev.val})');
					#end
					
					if (cast(i.prev.val, Comparable<Dynamic>).compare(v) < 0)
						i = i.prev;
					else
						break;
				}
				if (valid(m))
				{
					p.next = m;
					m.prev = p;
				}
				else
				{
					p.next = null;
					tail = p;
				}
				
				if (i == h)
				{
					n.prev = null;
					n.next = i;
					
					i.prev = n;
					h = n;
				}
				else
				{
					n.prev = i.prev;
					i.prev.next = n;
					
					n.next = i;
					i.prev = n;
				}
			}
			n = m;
		}
		
		return h;
	}
	
	function insertionSort(node:DLLNode<T>, cmp:T->T->Int):DLLNode<T>
	{
		var h = node;
		var n = h.next;
		while (valid(n))
		{
			var m = n.next;
			var p = n.prev;
			var v = n.val;
			
			if (cmp(v, p.val) < 0)
			{
				var i = p;
				
				while (i.hasPrev())
				{
					if (cmp(v, i.prev.val) < 0)
						i = i.prev;
					else
						break;
				}
				if (valid(m))
				{
					p.next = m;
					m.prev = p;
				}
				else
				{
					p.next = null;
					tail = p;
				}
				
				if (i == h)
				{
					n.prev = null;
					n.next = i;
					
					i.prev = n;
					h = n;
				}
				else
				{
					n.prev = i.prev;
					i.prev.next = n;
					
					n.next = i;
					i.prev = n;
				}
			}
			n = m;
		}
		
		return h;
	}
	
	inline function valid(node:DLLNode<T>):Bool
	{
		return node != null;
	}
	
	inline function getNode(x:T)
	{
		if (mReservedSize == 0 || mPoolSize == 0)
			return new DLLNode<T>(x, this);
		else
		{
			var n = mHeadPool;
			
			#if debug
			assert(n.prev == null, "node.prev == null");
			assert(valid(n.next), "node.next != null");
			#end
			
			mHeadPool = mHeadPool.next;
			mPoolSize--;
			
			n.next = null;
			n.val = x;
			return n;
		}
	}
	
	inline function putNode(x:DLLNode<T>):T
	{
		var val = x.val;
		if (mReservedSize > 0 && mPoolSize < mReservedSize)
		{
			mTailPool = mTailPool.next = x;
			x.val = cast null;
			
			#if debug
			assert(x.next == null, "x.next == null");
			assert(x.prev == null, "x.prev == null");
			#end
			
			mPoolSize++;
		}
		else
			x.mList = null;
		
		return val;
	}
}

#if (flash && generic)
@:generic
#end
#if doc
private
#end
class DLLIterator<T> implements de.polygonal.ds.Itr<T>
{
	var mF:DLL<T>;
	var mWalker:DLLNode<T>;
	var mHook:DLLNode<T>;
	
	public function new(f:DLL<T>)
	{
		mF = f;
		reset();
	}
	
	inline public function reset():Itr<T>
	{
		mWalker = mF.head;
		mHook = null;
		return this;
	}
	
	inline public function hasNext():Bool
	{
		return mWalker != null;
	}

	inline public function next():T
	{
		var x = mWalker.val;
		mHook = mWalker;
		mWalker = mWalker.next;
		return x;
	}
	
	inline public function remove()
	{
		#if debug
		assert(mHook != null, "call next() before removing an element");
		#end
		
		mF.unlink(mHook);
	}
}

#if (flash && generic)
@:generic
#end
#if doc
private
#end
class CircularDLLIterator<T> implements de.polygonal.ds.Itr<T>
{
	var mF:DLL<T>;
	var mWalker:DLLNode<T>;
	var mI:Int;
	var mS:Int;
	var mHook:DLLNode<T>;
	
	public function new(f:DLL<T>)
	{
		mF = f;
		reset();
	}
	
	inline public function reset():Itr<T>
	{
		mWalker = mF.head;
		mS = mF.size();
		mI = 0;
		mHook = null;
		return this;
	}
	
	inline public function hasNext():Bool
	{
		return mI < mS;
	}

	inline public function next():T
	{
		var x = mWalker.val;
		mHook = mWalker;
		mWalker = mWalker.next;
		mI++;
		return x;
	}
	
	inline public function remove()
	{
		#if debug
		assert(mI > 0, "call next() before removing an element");
		#end
		mF.unlink(mHook);
		mI--;
		mS--;
	}
}