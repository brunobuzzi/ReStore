﻿"Filed out from Dolphin Smalltalk 7"!

SSWDBStaticCollectionSpec subclass: #SSWDBSortedStaticCollectionSpec
	instanceVariableNames: 'orderingSpecs'
	classVariableNames: ''
	poolDictionaries: ''
	classInstanceVariableNames: ''!
SSWDBSortedStaticCollectionSpec guid: (GUID fromString: '{e4f21821-655e-11d5-b1df-0010a70883e2}')!
SSWDBSortedStaticCollectionSpec comment: 'Copyright 2000/2001 Solutions Software Limited'!
!SSWDBSortedStaticCollectionSpec categoriesForClass!Unclassified! !
!SSWDBSortedStaticCollectionSpec methodsFor!

dbInstancesFor: aCollectionProxy

	"Add the ordering"

	| instances |

	instances := super dbInstancesFor: aCollectionProxy.
	instances parser orderingSpecs: self orderingSpecs.

	^instances!

orderingSpecs

	"Derived from the sortBlock of the templateCollection"

	orderingSpecs isNil ifTrue: [self setOrderingSpecs].

	^orderingSpecs!

orderingSpecs: anOrderedCollection

	"Derived from the sortBlock of the templateCollection"

	orderingSpecs := anOrderedCollection!

queryClass

	"18/9/2000
	
	Return the class of select query appropriate for the receiver"
	
	^SSWSQLOrderedSelectQuery!

refreshCollectionForProxy: aCollectionProxy

	"We need to join to the target table in order to order the query (ie. sort the results correctly), therefore we may as well do a full recover"

	^self recoverCollectionForProxy: aCollectionProxy!

selectQueryIn: anSSWReStore

	"30/4/2001"

	| query |

	query := super selectQueryIn: anSSWReStore.

	self targetClass isPersistentBaseClass
	ifTrue:
		[(self orderingSpecs isEmpty or: [self orderingSpecs first isAscending])
			ifTrue: [query orderAscendingBy: self targetField]
			ifFalse: [query orderDescendingBy: self targetField]]
	ifFalse:
		[| targetTable |
		targetTable := anSSWReStore tableForClass: self targetClass.
		self orderingSpecs do: 
			[ :spec | 
			spec isAscending
				ifTrue: [query orderAscendingBy: (targetTable fieldAccessing: spec criteria)]
				ifFalse: [query orderDescendingBy: (targetTable fieldAccessing: spec criteria)]]].

	^query!

setOrderingSpecs

	self orderingSpecs: (self templateCollection orderingSpecsFor: self targetClass in: self reStore)! !
!SSWDBSortedStaticCollectionSpec categoriesFor: #dbInstancesFor:!accessing:derived!public! !
!SSWDBSortedStaticCollectionSpec categoriesFor: #orderingSpecs!accessing!public! !
!SSWDBSortedStaticCollectionSpec categoriesFor: #orderingSpecs:!accessing!public! !
!SSWDBSortedStaticCollectionSpec categoriesFor: #queryClass!constants!public! !
!SSWDBSortedStaticCollectionSpec categoriesFor: #refreshCollectionForProxy:!actions - api!public! !
!SSWDBSortedStaticCollectionSpec categoriesFor: #selectQueryIn:!accessing:derived!public! !
!SSWDBSortedStaticCollectionSpec categoriesFor: #setOrderingSpecs!accessing!initializing!public! !

