export function greetingPeriod(hour) {
  if (hour < 12) return "morning"
  if (hour < 18) return "afternoon"
  return "evening"
}
