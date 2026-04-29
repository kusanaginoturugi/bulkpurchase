import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["year", "month", "deadlineAt", "arrivalDate"]

  static schedules = {
    6: { deadlineAt: "2026-05-31T23:59", arrivalDate: "2026-06-13" },
    7: { deadlineAt: "2026-06-28T23:59", arrivalDate: "2026-07-11" },
    8: { deadlineAt: "2026-07-26T23:59", arrivalDate: "2026-08-08" },
    9: { deadlineAt: "2026-08-30T23:59", arrivalDate: "2026-09-12" },
    10: { deadlineAt: "2026-09-27T23:59", arrivalDate: "2026-10-11" },
    11: { deadlineAt: "2026-10-25T23:59", arrivalDate: "2026-11-07" },
    12: { deadlineAt: "2026-11-29T23:59", arrivalDate: "2026-12-12" }
  }

  autofill() {
    const year = Number(this.yearTarget.value)
    const month = Number(this.monthTarget.value)
    const schedule = this.constructor.schedules[month]

    if (year !== 2026 || !schedule) return

    this.deadlineAtTarget.value = schedule.deadlineAt
    this.arrivalDateTarget.value = schedule.arrivalDate
  }
}
