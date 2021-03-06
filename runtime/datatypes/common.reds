Red/System [
	Title:   "Common datatypes utility functions"
	Author:  "Nenad Rakocevic"
	File: 	 %common.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2012 Nenad Rakocevic. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/dockimbel/Red/blob/master/BSL-License.txt
	}
]

names!: alias struct! [
	buffer	[c-string!]								;-- datatype name string
	size	[integer!]								;-- buffer size - 1 (not counting terminal `!`)
	word	[red-word!]								;-- datatype name as word! value
]

name-table:   declare names! 						;-- datatype names table
action-table: declare int-ptr!						;-- actions jump table


set-type: func [										;@@ convert to macro?
	cell [cell!]
	type [integer!]
][
	cell/header: cell/header and type-mask or type
]

alloc-at-tail: func [
	blk		[red-block!]
	return: [cell!]
][
	alloc-tail as series! blk/node/value
]

alloc-tail: func [
	s		 [series!]
	return:  [cell!]
	/local 
		cell [red-value!]
][
	if (as byte-ptr! s/tail + 1) >= ((as byte-ptr! s + 1) + s/size) [
		s: expand-series s 0
	]
	
	cell: s/tail
	;-- ensure that cell is within series upper boundary
	assert (as byte-ptr! cell) < ((as byte-ptr! s + 1) + s/size)
	
	s/tail: cell + 1									;-- move tail to next cell
	cell
]

alloc-tail-unit: func [
	s		 [series!]
	unit 	 [integer!]
	return:  [byte-ptr!]
	/local 
		p	 [byte-ptr!]
][
	if ((as byte-ptr! s/tail) + unit) >= ((as byte-ptr! s + 1) + s/size) [
		s: expand-series s 0
	]
	
	p: as byte-ptr! s/tail
	;-- ensure that cell is within series upper boundary
	assert p < ((as byte-ptr! s + 1) + s/size)
	
	s/tail: as cell! p + unit							;-- move tail to next unit slot
	p
]

copy-cell: func [
	src		[cell!]
	dst		[cell!]
	return: [red-value!]
][
	copy-memory											;@@ optimize for 16 bytes copying
		as byte-ptr! dst
		as byte-ptr! src
		size? cell!
	dst
]

fire: func [
	[variadic]
	count	[integer!]
	list	[int-ptr!]
	/local
		arg1 [red-value!]
		arg2 [red-value!]
		arg3 [red-value!]
][
	assert count <= 5
	arg1: null
	arg2: null
	arg3: null
	
	count: count - 2
	unless zero? count [
		arg1: as red-value! list/3
		count: count - 1
		unless zero? count [
			arg2: as red-value! list/4
			count: count - 1
			unless zero? count [arg3: as red-value! list/5]
		]
	]
	stack/throw-error error/create as red-word! list/1 as red-word! list/2 arg1 arg2 arg3
]

type-check-alt: func [
	ref		 [red-value!]
	expected [red-typeset!]
	index	 [integer!]
	arg		 [red-value!]
	return:  [red-value!]
	/local
		bool [red-logic!]
][
	bool: as red-logic! ref
	either bool/value [type-check expected index arg][arg]
]

type-check: func [
	expected [red-typeset!]
	index	 [integer!]
	arg		 [red-value!]
	return:  [red-value!]
	/local
		bits [byte-ptr!]
		pos	 [byte-ptr!]								;-- required by BS_TEST_BIT
		set? [logic!]									;-- required by BS_TEST_BIT
][
	type: TYPE_OF(arg)
	bits: (as byte-ptr! expected) + 4
	BS_TEST_BIT(bits type set?)
	unless set? [ERR_EXPECT_ARGUMENT(type index)]
	arg													;-- pass-thru argument
]

words: context [
	spec:			-1
	body:			-1
	words:			-1
	logic!:			-1
	integer!:		-1
	any-type!:		-1
	repeat:			-1
	foreach:		-1
	map-each:		-1
	remove-each:	-1
	exit*:			-1
	return*:		-1
	self:			-1
	values:			-1
	
	any*:			-1
	break*:			-1
	copy:			-1
	end:			-1
	fail:			-1
	into:			-1
	opt:			-1
	not*:			-1
	quote:			-1
	reject:			-1
	set:			-1
	skip:			-1
	some:			-1
	thru:			-1
	to:				-1
	none:			-1
	pipe:			-1
	dash:			-1
	then:			-1
	if*:			-1
	remove:			-1
	while*:			-1
	insert:			-1
	only:			-1
	collect:		-1
	keep:			-1
	ahead:			-1
	after:			-1
	
	_true:			-1
	_false:			-1
	_yes:			-1
	_no:			-1
	_on:			-1
	_off:			-1
	
	_body:			as red-word! 0
	_windows:		as red-word! 0
	_syllable:		as red-word! 0
	_macosx:		as red-word! 0
	_linux:			as red-word! 0
	
	_push:			as red-word! 0
	_pop:			as red-word! 0
	_fetch:			as red-word! 0
	_match:			as red-word! 0
	_iterate:		as red-word! 0
	_paren:			as red-word! 0
	_anon:			as red-word! 0
	_body:			as red-word! 0
	_end:			as red-word! 0
	
	_on-parse-event: as red-word! 0
	_on-change*:	 as red-word! 0
	
	_type:			as red-word! 0
	_id:			as red-word! 0
	_try:			as red-word! 0
	
	
	errors: context [
		throw:		as red-word! 0
		note:		as red-word! 0
		syntax:		as red-word! 0
		script:		as red-word! 0
		math:		as red-word! 0
		access:		as red-word! 0
		user:		as red-word! 0
		internal:	as red-word! 0
	]

	build: does [
		spec:			symbol/make "spec"
		body:			symbol/make "body"
		words:			symbol/make "words"
		logic!:			symbol/make "logic!"
		integer!:		symbol/make "integer!"
		any-type!:		symbol/make "any-type!"
		exit*:			symbol/make "exit"
		return*:		symbol/make "return"

		windows:		symbol/make "Windows"
		syllable:		symbol/make "Syllable"
		macosx:			symbol/make "MacOSX"
		linux:			symbol/make "Linux"
		
		repeat:			symbol/make "repeat"
		foreach:		symbol/make "foreach"
		map-each:		symbol/make "map-each"
		remove-each:	symbol/make "remove-each"
		
		any*:			symbol/make "any"
		break*:			symbol/make "break"
		copy:			symbol/make "copy"
		end:			symbol/make "end"
		fail:			symbol/make "fail"
		into:			symbol/make "into"
		opt:			symbol/make "opt"
		not*:			symbol/make "not"
		quote:			symbol/make "quote"
		reject:			symbol/make "reject"
		set:			symbol/make "set"
		skip:			symbol/make "skip"
		some:			symbol/make "some"
		thru:			symbol/make "thru"
		to:				symbol/make "to"
		none:			symbol/make "none"
		pipe:			symbol/make "|"
		dash:			symbol/make "-"
		then:			symbol/make "then"
		if*:			symbol/make "if"
		remove:			symbol/make "remove"
		while*:			symbol/make "while"
		insert:			symbol/make "insert"
		only:			symbol/make "only"
		collect:		symbol/make "collect"
		keep:			symbol/make "keep"
		ahead:			symbol/make "ahead"
		after:			symbol/make "after"
		
		self:			symbol/make "self"
		values:			symbol/make "values"
		
		_true:			symbol/make "true"
		_false:			symbol/make "false"
		_yes:			symbol/make "yes"
		_no:			symbol/make "no"
		_on:			symbol/make "on"
		_off:			symbol/make "off"
		
		_windows:		_context/add-global windows
		_syllable:		_context/add-global syllable
		_macosx:		_context/add-global macosx
		_linux:			_context/add-global linux
		
		_push:			word/load "push"
		_pop:			word/load "pop"
		_fetch:			word/load "fetch"
		_match:			word/load "match"
		_iterate:		word/load "iterate"
		_paren:			word/load "paren"
		_anon:			word/load "<anon>"				;-- internal usage
		_body:			word/load "<body>"				;-- internal usage
		_end:			_context/add-global end
		
		_on-parse-event: word/load "on-parse-event"
		_on-change*:	 word/load "on-change*"
		
		_type:			word/load "type"
		_id:			word/load "id"
		_try:			word/load "try"
		
		errors/throw:	 word/load "throw"
		errors/note:	 word/load "note"
		errors/syntax:	 word/load "syntax"
		errors/script:	 word/load "script"
		errors/math:	 word/load "math"
		errors/access:	 word/load "access"
		errors/user:	 word/load "user"
		errors/internal: word/load "internal"
	]
]

refinements: context [
	local: 		as red-refinement! 0
	extern: 	as red-refinement! 0

	_part:		as red-refinement! 0
	_skip:		as red-refinement! 0

	build: does [
		local:	refinement/load "local"
		extern:	refinement/load "extern"

		_part:	refinement/load "part"
		_skip:	refinement/load "skip"
	]
]