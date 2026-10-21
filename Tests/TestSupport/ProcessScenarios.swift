import Foundation

/// Original MIT-licensed, fixed shell-builtin scenarios; no user-controlled script text.
public enum ProcessScenarios {
  public static let concurrentOutput = """
    i=0
    while [ "$i" -lt 4096 ]; do
      printf '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      printf 'FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210' >&2
      i=$((i + 1))
    done
    """
  public static let ignoresTermination = "trap '' TERM; printf '%s' ready; while :; do :; done"
  public static let abnormalSignal = "kill -KILL $$"
  public static let exactBoundary = "printf 'abcd'; printf 'EFGH' >&2"
  public static let oneByteOverflow = "printf 'abcd'; printf 'EFGHI' >&2"
  public static let successfulExit = "printf 'out'; printf 'err' >&2; exit 7"
  public static let exactContext = "printf '%s|%s|%s' \"$ONLY\" \"${HOME-unset}\" \"$PWD\""
  public static let immediateExit = "exit 0"
}
