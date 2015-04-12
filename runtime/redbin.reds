Red/System [
	Title:   "Redbin format encoder and decoder for Red runtime"
	Author:  "Qingtian Xie"
	File: 	 %redbin.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2015 Nenad Rakocevic & Xie Qingtian. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/dockimbel/Red/blob/master/BSL-License.txt
	}
]

#define redbin-compact-mask			01h
#define redbin-compressed-mask		02h
#define redbin-symbol-table-mask	04h

#define REDBIN_VALUES_MASK	40000000h
#define REDBIN_STACK_MASK	20000000h
#define REDBIN_SELF_MASK	10000000h

redbin: context [
	verbose: 0
	
	#enum redbin-value-type! [
		REDBIN_PADDING: 	0
		REDBIN_REFERENCE: 	255
	]
	
	root-base: as red-value! 0
	root-offset: 0
	
	preprocess-symbols: func [
		base 	[int-ptr!]
		/local
			syms	[int-ptr!]
			end		[int-ptr!]
			strings [c-string!]
	][
		syms:	 base + 2
		end:	 syms + base/value
		strings: as-c-string end
		
		while [syms < end][
			syms/1: symbol/make strings + syms/1
			syms: syms + 1
		]
	]
	
	decode-context: func [
		data	[int-ptr!]
		table	[int-ptr!]
		parent	[red-block!]
		return: [int-ptr!]
		/local
			ctx		[red-context!]
			slot	[red-word!]
			obj		[red-object!]
			values	[int-ptr!]
			sym		[int-ptr!]
			header	[integer!]
			values? [logic!]
			stack?	[logic!]
			self?	[logic!]
			slots	[integer!]
			new		[node!]
			symbols	[node!]
			i		[integer!]
	][
		header:  data/1
		values?: header and REDBIN_VALUES_MASK <> 0 
		stack?:	 header and REDBIN_STACK_MASK  <> 0 
		self?:	 header and REDBIN_SELF_MASK   <> 0 
		slots:	 data/2

		if values? [values: data + 2 + slots]
		
		new: _context/create slots stack? self?
		obj: as red-object! ALLOC_TAIL(parent)			;-- use an object to store the ctx node
		obj/header: TYPE_OBJECT
		obj/ctx:	new
		obj/class:	-1
		obj/on-set: null
		
		ctx: TO_CTX(new)
		symbols: ctx/symbols
		data: data + 2
		i: 0

		while [slots > 0][
			sym: table + data/1
			;-- create the words entries in the symbol table of the context
			slot: 		 as red-word! alloc-tail as series! symbols/value
			slot/header: TYPE_WORD
			slot/ctx: 	 new
			slot/symbol: sym/1
			slot/index:  i
			
			i: i + 1
			data: data + 1
			slots: slots - 1
		]
		data
	]
	
	decode-issue: func [
		data	[int-ptr!]
		table	[int-ptr!]
		parent	[red-block!]
		return: [int-ptr!]
		/local
			w	[red-word!]
			sym	[int-ptr!]
	][
		sym: table + data/2
		w: as red-word! ALLOC_TAIL(parent)
		w/header: TYPE_ISSUE
		w/symbol: sym/1
		data + 2
	]
	
	decode-word: func [
		data	[int-ptr!]
		table	[int-ptr!]
		parent	[red-block!]
		return: [int-ptr!]
		/local
			new	   [red-word!]
			w	   [red-word!]
			obj	   [red-object!]
			sym	   [int-ptr!]
			offset [integer!]
			ctx	   [node!]
	][
		sym: table + data/2								;-- get the decoded symbol
		new: as red-word! ALLOC_TAIL(parent)
		new/header: data/1 and FFh
		new/symbol: sym/1
		
		offset: data/3
		either offset = -1 [
			new/ctx: global-ctx
			w: _context/add-global sym/1
			new/index: w/index
		][
			obj: as red-object! block/rs-abs-at root offset + root-offset
			assert TYPE_OF(obj) = TYPE_OBJECT
			ctx: obj/ctx
			new/ctx: ctx
			either data/4 = -1 [
				new/index: _context/find-word TO_CTX(ctx) sym/1 yes
			][
				new/index: data/4
			]
		]
		data + 4
	]
	
	decode-string: func [
		data	[int-ptr!]
		parent	[red-block!]
		return: [int-ptr!]
		/local str header unit size s
	][
		header: data/1
		unit: header >>> 8 and FFh
		size: data/3 << (unit >> 1)					;-- optimized data/3 * unit

		str: as red-string! ALLOC_TAIL(parent)
		str/header: header and FFh					;-- implicit reset of all header flags
		str/head: 	data/2
		str/node: 	alloc-bytes size + unit			;-- account for NUL
		
		data: data + 3
		s: GET_BUFFER(str)
		copy-memory as byte-ptr! s/offset as byte-ptr! data size
		
		s/flags: s/flags and flag-unit-mask or unit
		s/tail: as cell! (as byte-ptr! s/offset) + size
		string/add-terminal-NUL as byte-ptr! s/tail unit
		
		data: as int-ptr! ((as byte-ptr! data) + size)
		either (as-integer data) and 3 = 0 [data][
			as int-ptr! ((as-integer data) + 4 and -4) ;-- align to upper 32-bit boundary
		]
	]

	decode-block: func [
		data	[int-ptr!]
		table	[int-ptr!]
		parent	[red-block!]
		return: [int-ptr!]
		/local blk size sz
	][
		size: data/3
		sz: size
		if zero? sz [sz: 1]
		#if debug? = yes [if verbose > 0 [print [#":" size #":"]]]
		
		blk: block/make-in parent sz
		blk/head: data/2
		blk/header: data/1 and FFh
		data: data + 3
		
		while [size > 0][
			data: decode-value data table blk
			size: size - 1
		]
		data
	]

	decode-value: func [
		data	[int-ptr!]
		table	[int-ptr!]
		parent	[red-block!]
		return: [int-ptr!]
		/local type
	][
		type: data/1 and FFh
		#if debug? = yes [if verbose > 0 [print [#"<" type #">"]]]
		
		switch type [
			REDBIN_PADDING	[
				decode-value data + 1 table parent
			]
			TYPE_DATATYPE	[
				copy-cell as cell! datatype/push data/2 ALLOC_TAIL(parent)
				stack/pop 1
				data + 2
			]
			TYPE_UNSET		[
				copy-cell unset-value ALLOC_TAIL(parent)
				data + 1
			]
			TYPE_NONE		[
				copy-cell none-value ALLOC_TAIL(parent)
				data + 1
			]
			TYPE_LOGIC		[
				copy-cell as cell! logic/push as logic! data/2 ALLOC_TAIL(parent)
				stack/pop 1
				data + 2
			]
			TYPE_PATH
			TYPE_LIT_PATH
			TYPE_SET_PATH
			TYPE_GET_PATH
			TYPE_BLOCK
			TYPE_PAREN		[decode-block data table parent]
			TYPE_STRING
			TYPE_FILE
			TYPE_URL		[decode-string data parent]
			TYPE_CHAR		[
				copy-cell as cell! char/push data/2 ALLOC_TAIL(parent)
				stack/pop 1
				data + 2
			]
			TYPE_INTEGER	[
				copy-cell as cell! integer/push data/2 ALLOC_TAIL(parent)
				stack/pop 1
				data + 2
			]
			TYPE_FLOAT	[
				copy-cell as cell! float/push64 data/2 data/3 ALLOC_TAIL(parent)
				stack/pop 1
				data + 3
			]
			TYPE_CONTEXT	[decode-context data table parent]
			TYPE_WORD
			TYPE_SET_WORD
			TYPE_LIT_WORD
			TYPE_GET_WORD
			TYPE_REFINEMENT [decode-word data table parent]
			TYPE_ISSUE		[decode-issue data table parent]
			TYPE_TYPESET	[
				typeset/make-at parent data/2 data/3 data/4
				data + 4
			]
			TYPE_NATIVE
			TYPE_ACTION
			TYPE_OP
			TYPE_FUNCTION
			TYPE_BITSET
			TYPE_POINT
			TYPE_OBJECT
			TYPE_ERROR
			TYPE_VECTOR
			REDBIN_REFERENCE [
				--NOT_IMPLEMENTED--
				data
			]
		]
	]

	decode: func [
		data	[byte-ptr!]
		parent	[red-block!]
		return: [red-value!]
		/local
			p			[byte-ptr!]
			end			[byte-ptr!]
			p4			[int-ptr!]
			compact?	[logic!]
			compressed? [logic!]
			sym-table?	[logic!]
			table		[int-ptr!]
			len			[integer!]
			count		[integer!]
			i			[integer!]
	][
		;----------------
		;-- decode header
		;----------------
		p: data
		unless all [					;-- magic="REDBIN"
			p/1 = #"R" p/2 = #"E" p/3 = #"D"
			p/4 = #"B" p/5 = #"I" p/6 = #"N"
		][
			print-line "Error: Not a Redbin file!"
			halt
		]
		p: p + 7						;-- skip magic(6 bytes) + version(1 byte)
		compact?:	 (as-integer p/1) and redbin-compact-mask = redbin-compact-mask
		compressed?: (as-integer p/1) and redbin-compressed-mask = redbin-compressed-mask
		sym-table?:  (as-integer p/1) and redbin-symbol-table-mask = redbin-symbol-table-mask
		p: p + 1
		p4: as int-ptr! p
		count: p4/1						;-- read records number
		len: p4/2						;-- read records size in bytes
		p4: p4 + 2						;-- skip both fields
		p: as byte-ptr! p4
		
		;----------------
		;-- get symbol table if we have it.
		;----------------
		table: null
		if sym-table? [
			preprocess-symbols p4
			table: p4 + 2
			p: p + 8 + (p4/1 * 4 + p4/2)
		]

		;----------------
		;-- decode values
		;----------------
		s: GET_BUFFER(parent)
		root-offset: (as-integer s/tail - s/offset) >> 4
		
		end: p + len
		#if debug? = yes [if verbose > 0 [i: 0]]
		
		while [p < end][
			#if debug? = yes [if verbose > 0 [print [i #":"]]]
			p: as byte-ptr! decode-value as int-ptr! p table parent
			#if debug? = yes [if verbose > 0 [i: i + 1 print lf]]
		]
		
		root-base: (block/rs-head parent) + root-offset
		root-base
	]
	
	boot-load: does [decode system/boot-data root]
]