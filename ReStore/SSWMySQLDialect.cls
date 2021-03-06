﻿"Filed out from Dolphin Smalltalk 7"!

SSWSQLDialect subclass: #SSWMySQLDialect
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	classInstanceVariableNames: ''!
SSWMySQLDialect guid: (GUID fromString: '{6645ca35-73aa-4a51-b909-d0cb2f7c228b}')!
SSWMySQLDialect comment: ''!
!SSWMySQLDialect categoriesForClass!Unclassified! !
!SSWMySQLDialect methodsFor!

boolean

	^'TINYINT'!

dialectSpecificFunctions

	^##(Dictionary new

		"String functions"
		at: #, put: 'CONCAT(%1,%2)';
		at: #size put: 'CHAR_LENGTH(%1)';
		at: #leftString: put: 'LEFT(%1,%2)';
		at: #rightString: put: 'RIGHT(%1,%2)';
		at: #asciiValue put: 'ASCII(%1)';
		at: #indexOfSubCollection: put: 'LOCATE(%2,%1)';
		at: #indexOfSubCollection:startingAt: put: 'LOCATE(%2,%1,%3)';
		at: #replaceAllOccurencesOf:with: put: 'REPLACE(%1,%2,%3)';
		at: #reverse put: 'REVERSE(%1)';
		at: #replaceFrom:length:with: put: 'INSERT(%1,%2,%3,%4)';

		"Date functions"
		at: #addDays: put: 'DATE_ADD(%1, INTERVAL %2 DAY)';
		at: #addMonths: put: 'DATE_ADD(%1, INTERVAL %2 MONTH)';
		at: #addYears: put: 'DATE_ADD(%1, INTERVAL %2 YEAR)';
		at: #subtractDays: put: 'DATE_SUB(%1, INTERVAL %2 DAY)';
		at: #weekday put: 'DAYNAME(%1)';
		at: #dayOfMonth put: 'DAYOFMONTH(%1)';
		at: #day put: 'DAYOFYEAR(%1)';
		at: #monthIndex put: 'MONTH(%1)';
		at: #monthName put: 'MONTHNAME(%1)';
		at: #year put: 'YEAR(%1)';

		yourself)!

maxVarchar

	"MySQL's limit is technically 65535, but this is for an entire row.
	2KB should be safe enough that we don't exceed this, whilst being reasonably large"

	^2048!

renameField: oldField to: newField in: aReStore

	| stream |

	stream := WriteStream on: (String new: 32).
	stream 
		nextPutAll: 'ALTER TABLE ';
		nextPutAll: newField table name;
		nextPutAll: ' CHANGE ';
		nextPutAll: oldField name;
		space.

	newField writeSQLDefinitionOn: stream.
	aReStore executeSQL: stream contents!

shouldMaskSuccessWithInfo

	^true!

supportsMultipleAddColumns

	^true!

time

	"Error seen with TIME columns in prepared statements in MySQL (tested 5.5 and 5.6) with ODBC driver version 05.03.0006:
		'07006: [MySQL][ODBC 5.3(a) Driver][mysqld-5.5.33-log]Conversion is not supported'
	Works fine with driver version 5.1.x.

	Not ideal, but fallback to DATETIME"

	^(self connection driverVersion beginsWith: '05.03.')
		ifTrue: [self timestamp]
		ifFalse: [super time]!

timestamp

	^'DATETIME'!

unsizedStringTypes

	"Full use of MEDIUMTEXT and LONGTEXT will require increasing the default maxColumnBytes (unrealistically so for LONGTEXT)"

	^OrderedCollection new
		add: (##((2 raisedTo: 16) - 1) "65535" -> 'TEXT');
		add: (##((2 raisedTo: 24) - 1) "16,777,215" -> 'MEDIUMTEXT');
		add: (##((2 raisedTo: 32) - 1) "4,294,967,295" -> 'LONGTEXT');
		yourself!

writeSQLForTime: aTime on: aStream

	self time = self timestamp
		ifTrue: [self writeSQLForTimeStamp: (TimeStamp time: aTime) on: aStream]
		ifFalse: [super writeSQLForTime: aTime on: aStream]! !
!SSWMySQLDialect categoriesFor: #boolean!datatypes!public! !
!SSWMySQLDialect categoriesFor: #dialectSpecificFunctions!constants!public! !
!SSWMySQLDialect categoriesFor: #maxVarchar!constants!public! !
!SSWMySQLDialect categoriesFor: #renameField:to:in:!maintenance!public! !
!SSWMySQLDialect categoriesFor: #shouldMaskSuccessWithInfo!public!testing! !
!SSWMySQLDialect categoriesFor: #supportsMultipleAddColumns!public!testing! !
!SSWMySQLDialect categoriesFor: #time!datatypes!public! !
!SSWMySQLDialect categoriesFor: #timestamp!datatypes!public! !
!SSWMySQLDialect categoriesFor: #unsizedStringTypes!datatypes!public! !
!SSWMySQLDialect categoriesFor: #writeSQLForTime:on:!public!writing sql! !

!SSWMySQLDialect class methodsFor!

dbmsName

	^'MySQL'! !
!SSWMySQLDialect class categoriesFor: #dbmsName!constants!public! !

