﻿"Filed out from Dolphin Smalltalk 7"!

SSWSQLDialect subclass: #SSWSQLServerDialect
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	classInstanceVariableNames: ''!
SSWSQLServerDialect guid: (GUID fromString: '{520d9399-40a8-4481-bf93-615e8a4eb465}')!
SSWSQLServerDialect comment: ''!
!SSWSQLServerDialect categoriesForClass!Unclassified! !
!SSWSQLServerDialect methodsFor!

boolean

	^'BIT'!

canDescribeParameters

	"Appears to be supported by the native ODBC driver, but flaky (doesn't work with > 1 param?), so let's act as if it doesn't work"

	^false!

cursorType

	^#keysetDriven!

date

	"SQL Server >= 2008 supports an explicit DATE type, however backwards-compatibility converts times to Strings depending on version of ODBC driver.
	As TIME suffers from the same issues and more (see implementation of time), use the legacy timestamp type for both dates and times"

	^self timestamp!

dialectSpecificFunctions

	^##(Dictionary new

		"Numeric functions"
		at: #rounded put: 'ROUND(%1,0)';

		"String functions"
		at: #, put: '(%1 + %2)';
		at: #leftString: put: 'LEFT(%1,%2)';
		at: #rightString: put: 'RIGHT(%1,%2)';
		at: #asciiValue put: 'ASCII(%1)';
		at: #indexOfSubCollection: put: 'CHARINDEX(%2,%1)';
		at: #midString:from: put: 'SUBSTRING(%1,%3,%2)';
		
		"Date functions"
		at: #addDays: put: 'DATEADD(''d'',%2,%1)';
		at: #addMonths: put: 'DATEADD(''m'',%2,%1)';
		at: #addYears: put: 'DATEADD(''yyyy'',%2,%1)';
		at: #dayOfMonth put: 'DATEPART(''d'',%1)';
		at: #monthIndex put: 'DATEPART(''m'',%1)';
		at: #year put: 'DATEPART(''yyyy'',%1)';

		yourself)!

double

	^'DOUBLE PRECISION'!

integer

	^'INT'!

maxCharacter

	^8000!

renameField: oldField to: newField in: aReStore

	aReStore executeSQL: ('EXEC sp_rename ''%1.%2'', ''%3'', ''COLUMN''' formatWith: newField table name with: oldField name with: newField name)!

renameTableNamed: oldName to: newName in: anSSWReStore

	anSSWReStore executeSQL: ('EXEC sp_rename ''%1'',''%2''' formatWith: oldName with: newName)!

shouldMaskSuccessWithInfo

	^true!

supportsImplicitTrueConditions

	^false!

time	

	"SQL Server >= 2008 supports its own TIME type (SQL_SS_TIME2) but is not compatible with standard SQL_TIME.
	Also backwards-compatibility converts times to Strings depending on version of ODBC driver.
	Therefore use the legacy timestamp type"

	^self timestamp!

timestamp

	^'DATETIME'!

writeSQLForDate: aDate on: aStream

	self writeSQLForTimeStamp: (TimeStamp date: aDate) on: aStream!

writeSQLForTime: aTime on: aStream

	self writeSQLForTimeStamp: (TimeStamp time: aTime) on: aStream! !
!SSWSQLServerDialect categoriesFor: #boolean!datatypes!public! !
!SSWSQLServerDialect categoriesFor: #canDescribeParameters!public!testing! !
!SSWSQLServerDialect categoriesFor: #cursorType!constants!public! !
!SSWSQLServerDialect categoriesFor: #date!datatypes!public! !
!SSWSQLServerDialect categoriesFor: #dialectSpecificFunctions!constants!public! !
!SSWSQLServerDialect categoriesFor: #double!datatypes!public! !
!SSWSQLServerDialect categoriesFor: #integer!datatypes!public! !
!SSWSQLServerDialect categoriesFor: #maxCharacter!constants!public! !
!SSWSQLServerDialect categoriesFor: #renameField:to:in:!maintenance!public! !
!SSWSQLServerDialect categoriesFor: #renameTableNamed:to:in:!maintenance!public! !
!SSWSQLServerDialect categoriesFor: #shouldMaskSuccessWithInfo!public!testing! !
!SSWSQLServerDialect categoriesFor: #supportsImplicitTrueConditions!public!testing! !
!SSWSQLServerDialect categoriesFor: #time!datatypes!public! !
!SSWSQLServerDialect categoriesFor: #timestamp!datatypes!public! !
!SSWSQLServerDialect categoriesFor: #writeSQLForDate:on:!public!writing sql! !
!SSWSQLServerDialect categoriesFor: #writeSQLForTime:on:!public!writing sql! !

!SSWSQLServerDialect class methodsFor!

dbmsName

	^'MICROSOFT SQL SERVER' ! !
!SSWSQLServerDialect class categoriesFor: #dbmsName!constants!public! !

