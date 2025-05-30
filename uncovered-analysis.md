# JSON Support Decoding - Uncovered Lines Analysis

## Summary
After analyzing all JSON Support decoding files, here are the uncovered lines that are NOT assertions:

### Array Decoding.swift
- **Lines 41-43**: Error recovery path when array start needs more data after reading '['
- **Line 58**: Default case in switch for unexpected character in `decodeNextArrayElement`

### Boolean Decoding.swift  
- **Line 13**: Default case for unexpected character when peeking for boolean value

### Decoding Stream.swift
- **Lines 11-15**: `reset()` method - entire method is uncovered
- **Line 60**: Error path when stream finished unexpectedly in `readCharacter()`
- **Line 77**: Error path when stream finished unexpectedly in `peekCharacter()`
- **Lines 124-137**: `read(untilCharacterIn:)` method - entire method is uncovered
- **Lines 297-304**: `needsMoreData` property getter - entire getter is uncovered
- **Line 341**: Error throwing case in `needsMoreData` property
- **Line 353**: Error throwing case in `decodingResult()`

### Number Decoding.swift
- **Line 38**: Error case for numbers with leading zeroes (throws Error.numberWithLeadingZeroes)
- **Lines 52-53**: `.needsMoreData` case when reading decimal point
- **Lines 75-76**: `.needsMoreData` case when reading exponent marker

### Object Decoding.swift
- **Line 45**: Error throwing for unexpected character when reading property name
- **Lines 51-52**: `.needsMoreData` case after reading '{'
- **Line 69**: Default case for unexpected character in `decodeNextObjectProperty`
- **Lines 75-76**: `.needsMoreData` case in `decodeNextObjectProperty`
- **Line 85**: Error throwing for unexpected character in next property
- **Line 109**: Error case in `readNextPropertyName`
- **Lines 123-126**: Assertion failure recovery path (includes assertionFailure on line 124)
- **Line 135**: `.needsMoreData` case when reading ':'
- **Lines 141-143**: Path for joining multiple property name fragments
- **Line 145**: Error case when reading ':' fails

### String Decoding.swift
- **Line 26**: Error throwing in `decodeStringFragments`
- **Line 39**: Error case in `readStringStart`
- **Lines 49-50**: Assertion failure recovery (includes assertionFailure on line 49)
- **Line 110**: Error case in `readRawStringFragments`
- **Lines 122-123**: `.needsMoreData` case when reading escaped character
- **Line 127**: Error case when reading escaped character
- **Line 160**: Case for invalid/low surrogate (onFragment("�"))
- **Lines 178-179**: `.needsMoreData` case when reading second part of surrogate pair
- **Line 181**: Error case for second unicode escape
- **Line 191**: Invalid surrogate pair case (onFragment("��"))
- **Lines 199-201**: Assertion failure recovery for invalid surrogate pair
- **Lines 212-214**: Assertion failure recovery for unexpected character
- **Lines 237-238**: Assertion failure recovery for invalid hex value
- **Lines 248-249**: Assertion failure recovery for invalid unicode scalar

### Value Decoding.swift
- **Lines 48-49**: `.needsMoreData` restore path for null decoding
- **Lines 56-57**: `.needsMoreData` restore path for boolean decoding  
- **Lines 70-71**: `.needsMoreData` restore path for string start
- **Lines 79-80**: `.needsMoreData` restore path for array start
- **Lines 88-99**: Entire object decoding path (lines 89-99)
- **Line 114**: `.needsMoreData` case for next array element
- **Lines 124-135**: Entire object property decoding path
- **Line 144**: Object case in nesting
- **Line 147**: `fatalError()` - unreachable code
- **Line 173**: Object case in `peekValueKind`
- **Line 185**: Default case for unexpected character in `peekValueKind`

### Null Decoding.swift
- All lines are covered

## Key Findings

1. **Most uncovered code paths are error handling or edge cases**, particularly:
   - `.needsMoreData` cases when streaming JSON
   - Error cases for malformed JSON
   - Assertion failure recovery paths

2. **The `reset()` method in Decoding Stream is completely uncovered** - this appears to be unused functionality

3. **Object decoding in Value Decoding is completely uncovered** - the tests only cover arrays, not objects

4. **Several utility methods are uncovered**:
   - `read(untilCharacterIn:)` in Decoding Stream
   - `needsMoreData` property getter in DecodingResult

5. **Many edge cases in string decoding are uncovered**, particularly around:
   - Unicode surrogate pair handling errors
   - Invalid escape sequences
   - Stream interruption during escape sequences