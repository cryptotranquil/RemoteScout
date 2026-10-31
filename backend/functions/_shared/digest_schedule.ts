export interface LocalDateTime {
  date: string;
  weekday: string;
  minuteOfDay: number;
}

export function localDateTime(
  date: Date,
  timeZone: string,
): LocalDateTime {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const value = (type: string) =>
    parts.find((part) => part.type === type)?.value;
  const year = value("year");
  const month = value("month");
  const day = value("day");
  const hour = Number(value("hour"));
  const minute = Number(value("minute"));
  if (
    !year || !month || !day || !Number.isInteger(hour) ||
    !Number.isInteger(minute)
  ) {
    throw new Error("Could not resolve local date and time");
  }
  return {
    date: `${year}-${month}-${day}`,
    weekday: value("weekday") ?? "",
    minuteOfDay: hour * 60 + minute,
  };
}

export function isDigestDue(
  now: Date,
  timeZone: string,
  digestTime: string,
): boolean {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(digestTime);
  if (!match) throw new Error(`Invalid digest time: ${digestTime}`);
  const targetMinute = Number(match[1]) * 60 + Number(match[2]);
  const currentMinute = localDateTime(now, timeZone).minuteOfDay;
  const minutesAfterTarget = (currentMinute - targetMinute + 1440) % 1440;
  return minutesAfterTarget < 5;
}

export function isWeekend(now: Date, timeZone: string): boolean {
  const weekday = localDateTime(now, timeZone).weekday;
  return weekday === "Sat" || weekday === "Sun";
}
