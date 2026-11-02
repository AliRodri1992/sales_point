import assert from "node:assert/strict"
import test from "node:test"
import { greetingPeriod } from "../app/javascript/lib/greeting_period.mjs"

test("greeting follows the clock across noon, evening and midnight", () => {
  for (const [hour, expected] of [[0, "morning"], [11, "morning"], [12, "afternoon"], [17, "afternoon"], [18, "evening"], [23, "evening"]]) {
    assert.equal(greetingPeriod(hour), expected)
  }
})
