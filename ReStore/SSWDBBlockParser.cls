﻿"Filed out from Dolphin Smalltalk 7"!

Object subclass: #SSWDBBlockParser
	instanceVariableNames: 'reStore argumentClass argumentTable referencedTables qualifyingConditions qualifyingTables orderingSpecs groupByFields activeReceiver accumulatedConditions currentConditions isCollectingAssociations fieldEncounters accumulatedConditionsStack isAccumulatingConditions'
	classVariableNames: ''
	poolDictionaries: ''
	classInstanceVariableNames: ''!
SSWDBBlockParser guid: (GUID fromString: '{5a3e3dcf-3990-11d5-b1df-444553540000}')!
SSWDBBlockParser comment: 'Copyright 2000/2001 Solutions Software Limited'!
!SSWDBBlockParser categoriesForClass!Unclassified! !
!SSWDBBlockParser methodsFor!

_parse: aOneArgBlock

	| blockArgument parseResult |

	blockArgument := self newBlockArgument.
	self activeReceiver: blockArgument.

	parseResult := aOneArgBlock value: blockArgument.

	self accumulatedConditions isEmpty ifFalse: 
		["Accumulated conditions arise from detection of inlined logical operators (and:, or:) during the parse. Add the parseResult (final condition) to these"
		self accumulatedConditions == self currentConditions 
			ifTrue: [self currentConditions add: parseResult]
			ifFalse: [self currentConditions become: parseResult].

		parseResult := self accumulatedConditions.
		self resetConditions].

	^parseResult!

accumulatedConditions
	^accumulatedConditions!

accumulatedConditions: anObject
	accumulatedConditions := anObject!

accumulatedConditionsStack
	^accumulatedConditionsStack!

accumulatedConditionsStack: anObject
	accumulatedConditionsStack := anObject!

activeReceiver
	^activeReceiver!

activeReceiver: anObject
	activeReceiver := anObject!

allFields

	^SSWSQLTableAllFields forTable: self argumentTable!

argumentClass

	"21/3/2001
	
	argumentClass stores the class of object that is intended to be the single argument
	of a block being parsed by the receiver"
	
	^argumentClass!

argumentClass: aClass

	"21/3/2001
	
	argumentClass stores the class of object that is intended to be the single argument
	of a block being parsed by the receiver"
	
	argumentClass := aClass!

argumentTable

	"argumentTable stores the SSWDBTable associated with the receiver's argumentClass.
	Normally this is deduced from the reStore but can be set explicitly if different"

	^argumentTable ifNil: [self reStore tableForClass: self argumentClass]!

argumentTable: anSSWDBTable

	"argumentTable stores the SSWDBTable associated with the receiver's argumentClass.
	Normally this is deduced from the reStore but can be set explicitly if different"

	argumentTable := anSSWDBTable!

beUnsorted

	self orderingSpecs: OrderedCollection new!

collectQueryFrom: aOneArgBlock

	"Patched for issue 120-014
	
	aOneArgBlock should be of the form [ :cd | cd releaseDate] or [ :cd | cd label name], 
	i.e. reference a Date/String/Number etc. field"

	| targetFields |

	"We need to deduce the targetFields first since this affects the behavior of newSelectQuery"
	targetFields := self targetFieldsFrom: aOneArgBlock.

	^self newSelectQuery
		fields: targetFields;
		tables: self includedTables;
		conditions: self qualifyingConditions;
		yourself!

copy

	"27/3/2001"
	
	^self shallowCopy
		qualifyingConditions: self qualifyingConditions copy;
		qualifyingTables: self qualifyingTables copy;
		orderingSpecs: self orderingSpecs copy;
		groupByFields: self groupByFields copy;
		yourself!

currentConditions
	^currentConditions!

currentConditions: anObject
	currentConditions := anObject!

deleteQueryFrom: aOneArgBlock

	| conditions |
	
	self reset.
	
	conditions := self parse: aOneArgBlock.
	(conditions isKindOf: SSWDBBlockEvaluator) ifTrue: [conditions := SSWSQLConditionCollection forAND].

	^SSWSQLDeleteQuery new
		tables: self includedTables;
		conditions: (conditions sqlAnd: self qualifyingConditions);
		yourself!

fieldEncounters

	"fieldEncounters stores an OrderedCollection of fields encountered during a parse, in the order they were encountered"

	^fieldEncounters!

fieldEncounters: anOrderedCollection

	"fieldEncounters stores an OrderedCollection of fields encountered during a parse, in the order they were encountered"

	fieldEncounters := anOrderedCollection!

groupByFields
	^groupByFields!

groupByFields: anObject
	groupByFields := anObject!

handleMustBeBooleanIn: aCondition

	"Private - aCondition(Collection) has been subject to an inlined and: / or: message in a query block, resulting in a mustBeBoolean send.
	Deduce which from the original sender's bytecodes, returning the appropriate value to ensure the argument block is evaluated (true for and:, false for or:).
	Also update the receiver to ensure this condition is combined with the eventual result"

	| senderFrame bytecodes ip bytecode length nextBytecode jumpOffset blockEndpoint temp |

	senderFrame := Processor activeProcess topFrame sender sender.
	bytecodes := senderFrame method byteCodes.
	ip := senderFrame ip.
	bytecode := bytecodes at: ip.
	length := ByteCodeDispatcher lengthOfInstruction: bytecode.
	nextBytecode := bytecodes at: ip + length.

	(nextBytecode = OpcodePool.ReturnFalse or: [nextBytecode = OpcodePool.ReturnPseudo "ReturnTrue" or: [(bytecodes at: ip + 2) = OpcodePool.ReturnFromBlock "Jump+2 over Push<result>; ReturnFromBlock"]]) 
	ifTrue: 
		[blockEndpoint := SmallInteger maximum]
	ifFalse: 
		[(bytecode = OpcodePool.LongJumpIfFalse or: [bytecode = OpcodePool.LongJumpIfTrue]) 
		ifTrue: 
			[jumpOffset := length + (bytecodes swordAtOffset: ip)]
		ifFalse: 
			[(bytecode = OpcodePool.NearJumpIfFalse or: [bytecode = OpcodePool.NearJumpIfTrue]) 
				ifTrue: [jumpOffset := length + (bytecodes sbyteAtOffset: ip)]
				ifFalse: [jumpOffset := length + (bytecode - ##(OpcodePool.ShortJumpIfFalse - 1))]].
		blockEndpoint := ip + jumpOffset].

	self isAccumulatingConditions: true.

	"First possibility - last condition within a sequence of OR tests"
	(nextBytecode = OpcodePool.PushPseudo "PushTrue" or: [nextBytecode = OpcodePool.ReturnPseudo "ReturnTrue"]) ifTrue:
		[self currentConditions isEmpty
		ifTrue: 
			[self currentConditions add: aCondition; beOR; addLast: (self newConditionCollection blockEndpoint: blockEndpoint; yourself).
			self currentConditions: self currentConditions last]
		ifFalse: 
			[self currentConditions add: aCondition.
			temp := self newConditionCollection beOR.
			temp _add: temp "will become: currentCondiitions"; add: (self newConditionCollection blockEndpoint: blockEndpoint; yourself).
			self currentConditions become: temp.
			self currentConditions: self currentConditions last].
		^false].

	"Second possibility - condition within a sequence of OR tests, but not the last"
	(bytecode = OpcodePool.NearJumpIfTrue or: [bytecode = OpcodePool.LongJumpIfTrue]) ifTrue:
		[self currentConditions add: aCondition; beOR.
		^false].

	"and: possibilities"
	((bytecode between: 118 and: 125 "JumpIfFalse+offsets") or: [bytecode  = OpcodePool.NearJumpIfFalse or: [bytecode = OpcodePool.LongJumpIfFalse]]) ifTrue:
		["For and:, a PushFalse bytecode would be after the jump"
		nextBytecode := bytecodes at: blockEndpoint.
		(nextBytecode = ##(OpcodePool.PushPseudo+1) "PushFalse" or: [nextBytecode = OpcodePool.ReturnFalse]) ifFalse: 
			["Condition within a sequence of and: tests but not the last"
			self currentConditions add: aCondition; beAND. 
			^true].
		"Last condition in a sequence of and: tests"
		self currentConditions isEmpty 
		ifTrue: 
			[self currentConditions add: aCondition; beAND; blockEndpoint: blockEndpoint; addLast: (self newConditionCollection blockEndpoint: blockEndpoint; yourself).
			self currentConditions: self currentConditions last]
		ifFalse: 
			[self currentConditions add: aCondition.
			temp := self newConditionCollection beAND.
			temp _add: temp "will become: currentCondiitions"; add: (self newConditionCollection blockEndpoint: blockEndpoint; yourself).
			self currentConditions become: temp.
			self currentConditions: self currentConditions last].
		^true].

	self parseError: 'unexpected bytecodes encountered during and: / or: block parsing'!

hasAccumulatedConditions

	^self accumulatedConditions isEmpty not!

hasGrouping

	^self groupByFields isEmpty not!

hasOrdering

	^self orderingSpecs isEmpty not!

includedTables

	"21/3/2001
	
	Return those tables included in the query generated by the receiver.
	This is the referencedTables, without duplicated entries"
	
	^self referencedTables withoutDuplicates!

isAccumulatingConditions
	^isAccumulatingConditions!

isAccumulatingConditions: anObject
	isAccumulatingConditions := anObject!

isCollectingAssociations

	^isCollectingAssociations ifNil: [false]!

isCollectingAssociations: anObject
	isCollectingAssociations := anObject!

modifyQueryFrom: aOneArgBlock

	"Patched for issue 120-009"
	
	| updates |
	
	self reset.
	
	updates := (self parseForModify: aOneArgBlock) asFieldAssignment.
	updates field table == self argumentTable ifFalse: [self error: 'Only single-table updates supported'].
	
	^SSWSQLUpdateQuery new
		tables: (SSWSQLTableCollection with: self argumentTable);
		fieldUpdates: updates;
		conditions: self qualifyingConditions;
		yourself!

newBlockArgument

	"21/3/2001
	
	Create and return a new SSWDBBlockArgument to parse a block with"
	
	^SSWDBBlockArgument new 
		parser: self; 
		currentClass: self argumentClass;
		yourself!

newCondition

	| newCondition |

	newCondition := SSWDBQueryCondition new.
	newCondition parser: self.

	self hasAccumulatedConditions ifTrue: 
		[self isAccumulatingConditions
		ifTrue: 
			[self isAccumulatingConditions: false. 
			self currentConditions postCondition: newCondition]
		ifFalse: 
			[self pushAccumulatedConditions]].

	^newCondition!

newConditionCollection

	^SSWDBQueryConditionCollection new
		parser: self;
		yourself!

newReceiverFor: aField from: aBlockEvaluator

	"Private - Create and return a new SSWDBBlockReceiver to receive (and parse) messages for the class of object which is referenced by aField"

	| table occurrences |

	self fieldEncounters addLast: aField.

	table := self reStore tableForClass: aField targetClass.

	"Check for duplicate appearances (via different links) of the same table. Alias accordingly"
	(self referencedTables tableJoinedWithField: aField)
	ifNil:
		[occurrences := self referencedTables occurrencesOf: table.
		occurrences > 0 ifTrue: [table := SSWDBQueryTable forRepetition: occurrences of: table].
		self referencedTables add: table joinedWithField: aField]
	ifNotNil: 
		[ :joinedTable | table := joinedTable].

	self activeReceiver: 
		(SSWDBBlockReceiver new
			parser: self;
			currentClass: aField targetClass;
			currentTable: table;
			path: (aBlockEvaluator path, (Array with: aField accessor));
			yourself).

	^self activeReceiver!

newSelectQuery

	"Return a new, initialized SelectQuery of the approriate class"

	^self hasGrouping 
	ifTrue:
		[SSWSQLAggregatedOrderedSelectQuery new
			groupByFields: self groupByFields;
			orderingSpecs: self orderingSpecs;
			yourself]
	ifFalse:
		[self hasOrdering
		ifTrue: 
			[SSWSQLOrderedSelectQuery new
				orderingSpecs: self orderingSpecs;
				yourself]
		ifFalse: 
			[SSWSQLSelectQuery new]]!

orderingSpecs

	"orderingSpecs stores an OrderedCollection of SSWDBOrderingSpecs
	which are applied to all SelectQueries generated by the receiver.

	If empty, the query remains unordered"

	^orderingSpecs!

orderingSpecs: anOrderedCollection

	"orderingSpecs stores an OrderedCollection of SSWDBOrderingSpecs
	which are applied to all SelectQueries generated by the receiver.

	If empty, the query remains unordered"

	orderingSpecs := anOrderedCollection!

orWith: aBlockParser

	"'OR' the receiver with the qualifying conditions of aBlockParser"

	self qualifyingConditions: (self qualifyingConditions sqlOr: aBlockParser qualifyingConditions)
!

parse: aOneArgBlock

	"Private - 14/8/2000
	
	Parse aOneArgBlock, returning the resulting SSWSQLConditionCollection"

	^(self _parse: aOneArgBlock) asSQLConditions!

parseError: aString

	"Private - 21/3/2001
	
	Raise a suitable error"
	
	^self parseError: aString with: nil!

parseError: aString with: anObject

	"Private - Raise a suitable error"
	
	^SSWDBParseError signal: ('Cannot parse block - ', aString) with: anObject!

parseForModify: aOneArgBlock

	"Private - Created for issue 120-009
	
	Parse aOneArgBlock, returning the resulting SSWSQLConditionCollection.
	Indicate to the parsing components that this is for a modify instruction"

	^aOneArgBlock value: (self newBlockArgument isForModify: true; yourself)!

parseSortBlock: aTwoArgBlock

	"Parse aTwoArgBlock, which should be a 'simple' sort block (see SSWDBInstancesCollection>>sortBlock)
	returning the resulting SSWSQLConditionCollection"

	| isInverted blockArgument parseResult|

	self reset.

	isInverted := false.
	blockArgument := self newBlockArgument.
	self activeReceiver: blockArgument.

	parseResult := aTwoArgBlock value: blockArgument value: SSWDBDumbArgument current.
	parseResult == SSWDBDumbArgument current ifTrue: 
		["Consider inverse sort block, e.g. [ :a :b | b name > a name] (NB does not work in all cases)"
		isInverted := true.
		self reset.
		blockArgument := self newBlockArgument.
		self activeReceiver: blockArgument.
		parseResult := aTwoArgBlock value: SSWDBDumbArgument current value: blockArgument].

	self accumulatedConditions isEmpty ifFalse:
		["Accumulated conditions arise from detection of inlined tests (and:, or:) during the parse. Add the parseResult (final condition) to these"
		self accumulatedConditions == self currentConditions 
			ifTrue: [self currentConditions add: parseResult]
			ifFalse: [self currentConditions become: parseResult].
		parseResult := self accumulatedConditions].

	isInverted ifTrue: [parseResult flattened do: [ :each | each operator invert]].

	self qualifyingTables: (self qualifyingTables merge: self referencedTables withoutDuplicates).

	^parseResult!

popAccumulatedConditions

	| popped |

	self accumulatedConditionsStack isEmpty ifTrue: [^self resetConditions].

	popped := self accumulatedConditionsStack removeLast.
	self 
		accumulatedConditions: popped key;
		currentConditions: popped value!

projectQueryFrom: aOneArgBlock

	"Enrich the collect query generated from aOneArgBlock to group non-aggregated fields"

	| targetFields |

	"We need to deduce the targetFields first since this affects the behavior of newSelectQuery"
	targetFields := self targetFieldsFrom: aOneArgBlock.
	targetFields isAllInTable 
		ifTrue: [targetFields table = self argumentTable ifFalse: [self groupByFields: (SSWSQLFieldCollection with: targetFields table idField)]]
		ifFalse: [self groupByFields: (targetFields reject: [ :each | each hasAggregateFunction])].

	^self newSelectQuery
		fields: targetFields;
		tables: self includedTables;
		conditions: self qualifyingConditions;
		yourself!

pushAccumulatedConditions

	self accumulatedConditionsStack addLast: (self accumulatedConditions -> self currentConditions).
	self resetConditions!

qualifyingConditions

	"27/3/01
	
	qualifyingConditions stores a static condition collection which is ANDed with 
	the conditions of any query generated by the receiver (empty by default).
	
	This enables the receiver to be used for queries focusing on a subset of a table, 
	e.g. if the receiver's qualifyingConditions were (equivalent to) [ :cd | cd label name = '4AD'],
	then the receiver could be used to focus only on CDs issued by 4AD"
	
	^qualifyingConditions!

qualifyingConditions: anSSWSQLConditionCollection

	"27/3/01
	
	qualifyingConditions stores a static condition collection which is ANDed with 
	the conditions of any query generated by the receiver (empty by default).
	
	This enables the receiver to be used for queries focusing on a subset of a table, 
	e.g. if the receiver's qualifyingConditions were (equivalent to) [ :cd | cd label name = '4AD'],
	then the receiver could be used to focus only on CDs issued by 4AD"
	
	qualifyingConditions := anSSWSQLConditionCollection!

qualifyingTables

	"27/3/01
	
	qualifyingTables stores the tables encountered when creating qualifyingConditions"
	
	^qualifyingTables!

qualifyingTables: anSSWSQLJoinedTableCollection

	"27/3/01
	
	qualifyingTables stores the tables encountered when creating qualifyingConditions"
	
	qualifyingTables := anSSWSQLJoinedTableCollection!

qualifyWith: aOneArgBlock

	"27/3/2001
	
	Set the receiver's qualifyingCondition based on aOneArgBlock"

	| parsed |

	self reset.
	
	parsed := self parse: aOneArgBlock.
	(parsed isKindOf: SSWDBBlockEvaluator) ifTrue: [parsed := parsed implicitEqualsTrue].

	self 
		qualifyingConditions: (self qualifyingConditions sqlAnd: parsed);
		qualifyingTables: (self qualifyingTables merge: self referencedTables withoutDuplicates)!

referencedTables

	"14/8/2000
	
	referencedTables stores the SSWDBTables that are referenced when parsing a block,
	in the order in which they were referenced, together with the joining fields 
	(SSWJoinedTableCollection hold both together"
	
	^referencedTables!

referencedTables: anSSWJoinedTableCollection

	"14/8/2000
	
	referencedTables stores the SSWDBTables that are referenced when parsing a block,
	in the order in which they were referenced, together with the joining fields 
	(SSWJoinedTableCollection hold both together"
	
	referencedTables := anSSWJoinedTableCollection!

rejectQueryFrom: aOneArgBlock

	"23/3/2001"
	
	| conditions |
	
	self reset.
	
	"Invert (not) the parse: result to turn select into reject"
	conditions := (self parse: aOneArgBlock) not.

	^self newSelectQuery
		fields: self allFields;
		tables: self includedTables;
		conditions: (conditions sqlAnd: self qualifyingConditions);
		yourself!

reset

	"Private - 23/3/2001
	
	Reset the receiver for a new parsing session"
	self referencedTables: (SSWSQLLeftJoinedTableCollection with: self argumentTable).
	
	self qualifyingTables isNil ifFalse: [self referencedTables merge: self qualifyingTables].

	self
		groupByFields: SSWSQLFieldCollection new;
		resetConditions;
		accumulatedConditionsStack: OrderedCollection new;
		fieldEncounters: OrderedCollection new!

resetConditions

	self
		currentConditions: self newConditionCollection;
		accumulatedConditions: self currentConditions;
		isAccumulatingConditions: false!

reStore

	"14/8/2000
	
	reStore stores the SSWReStore for which the receiver parses blocks"
	
	^reStore!

reStore: anSSWReStore

	"14/8/2000
	
	reStore stores the SSWReStore for which the receiver parses blocks"
	
	reStore := anSSWReStore!

selectQueryFrom: aOneArgBlock

	"14/8/2000"
	
	| conditions |
	
	self reset.

	conditions := self parse: aOneArgBlock.

	^self newSelectQuery
		fields: self allFields;
		tables: self includedTables;
		conditions: (conditions sqlAnd: self qualifyingConditions);
		yourself!

sortBlock: aTwoArgBlock

	| sortConditions |

	[aTwoArgBlock isDefaultSortBlock
	ifTrue: 
		["Default <= implementation"
		sortConditions := self parseSortBlock: [ :a :b | a <= b] ]
	ifFalse: 
		[sortConditions := self parseSortBlock: aTwoArgBlock]] 
			on:	SSWDBParseError
			do:	[ :error | 
				error isFinalFieldError
					ifTrue: [error resume: nil]
					ifFalse: [error pass]].

	"For SQL ordering we require a flat collection. Also equality conditions are ignored.
	Thus (e.g.) 
		(p1 surname < p2 surname) | ((p1 surname = p2 surname) & (p1 firstName < p2 firstName))
	becomes:
		order by SURNAME asc, FIRST_NAME asc"
	sortConditions := sortConditions flattened reject: [ :each | each operator messageSelector = #=].

	self orderingSpecs: (sortConditions collect: [ :each | each asOrderingSpec])!

tableForClass: aClass

	^aClass == self argumentClass 
		ifTrue: [self argumentTable]
		ifFalse: [self reStore tableForClass: aClass]!

targetFieldsFrom: aOneArgBlock
	
	| targetFields nonAggregateFields |

	self reset.
	targetFields := (self _parse: aOneArgBlock) asSQLFields.

	"Parse result can be a single field or multiple depending on the block, e.g. [ :each | each name] or [ :each | each name || each age]"
	targetFields isFieldCollection ifFalse: [targetFields := SSWSQLFieldCollection with: targetFields].

	"If we have accumulated aggregated functions, ensure groupByFields are updated accordingly"
	nonAggregateFields := targetFields reject: [ :each | each hasAggregateFunction].
	nonAggregateFields size < targetFields size ifTrue: [self groupByFields: nonAggregateFields].

	^targetFields!

unprocessedConditionsCombinedWith: aCondition

	"Combine any unprocessed conditions left over from inlined messages with aCondition.
	Return the combined conditions, or aCondition if none"

	| ip conditions |

	"This line is obviously very sensitive to the overall implementation of the parser.
	It could be rewritten to detect the correct frame programatically but this implementation is more efficient"
	ip := Processor activeProcess topFrame sender sender sender sender sender ip.
	ip < self currentConditions blockEndpoint ifTrue: [^aCondition].

	"Accumulated conditions arise from detection of inlined logical operators (and:, or:) during the parse. Add the parseResult (final condition) to these"
	self accumulatedConditions == self currentConditions 
		ifTrue: [self currentConditions add: aCondition]
		ifFalse: [self currentConditions become: aCondition].

	conditions := self accumulatedConditions.
	self popAccumulatedConditions.
	^conditions!

unprocessedConditionsCombinedWithArgument: aCondition

	"Combine any unprocessed conditions left over from inlined messages with aCondition, which is the argument of a combination operation (&, | or ||).
	The argument must be combined BEFORE the receiver.
	Return the combined conditions, or aCondition if none"

	self hasAccumulatedConditions ifFalse: 
		[self popAccumulatedConditions.
		^aCondition].

	^self unprocessedConditionsCombinedWith: aCondition!

unprocessedConditionsCombinedWithReceiver: aCondition

	"Combine any unprocessed conditions left over from inlined messages with aCondition, which is the receiver of a combination operation (&, | or ||).
	Return the combined conditions, or aCondition if none"

	self hasAccumulatedConditions ifFalse: [^aCondition].

	aCondition == self currentConditions postCondition ifFalse: [self pushAccumulatedConditions. ^aCondition].

	^self unprocessedConditionsCombinedWith: aCondition! !
!SSWDBBlockParser categoriesFor: #_parse:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #accumulatedConditions!accessing!public! !
!SSWDBBlockParser categoriesFor: #accumulatedConditions:!accessing!public! !
!SSWDBBlockParser categoriesFor: #accumulatedConditionsStack!accessing!public! !
!SSWDBBlockParser categoriesFor: #accumulatedConditionsStack:!accessing!public! !
!SSWDBBlockParser categoriesFor: #activeReceiver!accessing!public! !
!SSWDBBlockParser categoriesFor: #activeReceiver:!accessing!public! !
!SSWDBBlockParser categoriesFor: #allFields!accessing!public! !
!SSWDBBlockParser categoriesFor: #argumentClass!accessing!public! !
!SSWDBBlockParser categoriesFor: #argumentClass:!accessing!public! !
!SSWDBBlockParser categoriesFor: #argumentTable!accessing!public! !
!SSWDBBlockParser categoriesFor: #argumentTable:!accessing!public! !
!SSWDBBlockParser categoriesFor: #beUnsorted!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #collectQueryFrom:!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #copy!copying!public! !
!SSWDBBlockParser categoriesFor: #currentConditions!accessing!public! !
!SSWDBBlockParser categoriesFor: #currentConditions:!accessing!public! !
!SSWDBBlockParser categoriesFor: #deleteQueryFrom:!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #fieldEncounters!accessing!public! !
!SSWDBBlockParser categoriesFor: #fieldEncounters:!accessing!public! !
!SSWDBBlockParser categoriesFor: #groupByFields!accessing!public! !
!SSWDBBlockParser categoriesFor: #groupByFields:!accessing!public! !
!SSWDBBlockParser categoriesFor: #handleMustBeBooleanIn:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #hasAccumulatedConditions!public!testing! !
!SSWDBBlockParser categoriesFor: #hasGrouping!public!testing! !
!SSWDBBlockParser categoriesFor: #hasOrdering!public!testing! !
!SSWDBBlockParser categoriesFor: #includedTables!evaluating!public! !
!SSWDBBlockParser categoriesFor: #isAccumulatingConditions!accessing!public! !
!SSWDBBlockParser categoriesFor: #isAccumulatingConditions:!accessing!public! !
!SSWDBBlockParser categoriesFor: #isCollectingAssociations!accessing!public! !
!SSWDBBlockParser categoriesFor: #isCollectingAssociations:!accessing!public! !
!SSWDBBlockParser categoriesFor: #modifyQueryFrom:!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #newBlockArgument!evaluating!public! !
!SSWDBBlockParser categoriesFor: #newCondition!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #newConditionCollection!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #newReceiverFor:from:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #newSelectQuery!evaluating!public! !
!SSWDBBlockParser categoriesFor: #orderingSpecs!accessing!public! !
!SSWDBBlockParser categoriesFor: #orderingSpecs:!accessing!public! !
!SSWDBBlockParser categoriesFor: #orWith:!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #parse:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #parseError:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #parseError:with:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #parseForModify:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #parseSortBlock:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #popAccumulatedConditions!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #projectQueryFrom:!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #pushAccumulatedConditions!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #qualifyingConditions!accessing!public! !
!SSWDBBlockParser categoriesFor: #qualifyingConditions:!accessing!public! !
!SSWDBBlockParser categoriesFor: #qualifyingTables!accessing!public! !
!SSWDBBlockParser categoriesFor: #qualifyingTables:!accessing!public! !
!SSWDBBlockParser categoriesFor: #qualifyWith:!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #referencedTables!accessing!public! !
!SSWDBBlockParser categoriesFor: #referencedTables:!accessing!public! !
!SSWDBBlockParser categoriesFor: #rejectQueryFrom:!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #reset!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #resetConditions!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #reStore!accessing!public! !
!SSWDBBlockParser categoriesFor: #reStore:!accessing!public! !
!SSWDBBlockParser categoriesFor: #selectQueryFrom:!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #sortBlock:!parsing - api!public! !
!SSWDBBlockParser categoriesFor: #tableForClass:!evaluating!public! !
!SSWDBBlockParser categoriesFor: #targetFieldsFrom:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #unprocessedConditionsCombinedWith:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #unprocessedConditionsCombinedWithArgument:!parsing - internal!private! !
!SSWDBBlockParser categoriesFor: #unprocessedConditionsCombinedWithReceiver:!parsing - internal!private! !

!SSWDBBlockParser class methodsFor!

new

	"21/3/2001"
	
	^super new
		qualifyingConditions: SSWSQLConditionCollection forAND;
		qualifyingTables: SSWSQLLeftJoinedTableCollection new;
		groupByFields: SSWSQLFieldCollection new;
		orderingSpecs: OrderedCollection new;
		accumulatedConditionsStack: OrderedCollection new;
		resetConditions;
		yourself!

newForReStore: anSSWReStore argumentClass: aClass

	"21/3/2001"
	
	^self new
		reStore: anSSWReStore;
		argumentClass: aClass;
		yourself! !
!SSWDBBlockParser class categoriesFor: #new!instance creation!public! !
!SSWDBBlockParser class categoriesFor: #newForReStore:argumentClass:!instance creation!public! !

