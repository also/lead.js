export function splitKeysAndValue(keysAndValue) {
  keysAndValue = [...keysAndValue];
  const value = keysAndValue.pop();
  const keys = keysAndValue;
  return {keys, value};
}
