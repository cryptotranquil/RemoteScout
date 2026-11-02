import { XMLParser } from "npm:fast-xml-parser@5.2.5";

const parser = new XMLParser({
  ignoreAttributes: true,
  processEntities: true,
  trimValues: true,
});

export interface ParsedRssItem {
  id: string;
  title: string;
  link: string;
  location: string;
  company: string;
  description: string;
  type: string;
  pubDate?: string;
}

function text(value: unknown): string {
  if (typeof value === "string" || typeof value === "number") {
    return String(value).trim();
  }
  if (typeof value === "object" && value !== null && "#text" in value) {
    return text((value as Record<string, unknown>)["#text"]);
  }
  return "";
}

export function parseWeWorkRemotelyRss(xml: string): ParsedRssItem[] {
  const parsed = parser.parse(xml) as {
    rss?: { channel?: { item?: unknown | unknown[] } };
  };
  const items = parsed.rss?.channel?.item;
  if (items == null) return [];
  const list = Array.isArray(items) ? items : [items];

  return list.flatMap((value): ParsedRssItem[] => {
    if (typeof value !== "object" || value === null) return [];
    const item = value as Record<string, unknown>;
    const title = text(item.title);
    const link = text(item.link);
    const guid = text(item.guid) || link;
    if (!title || !link || !guid) return [];
    const separator = title.indexOf(":");
    const company = separator > 0 ? title.slice(0, separator).trim() : "";
    const location = [
      text(item.region),
      text(item.country),
      text(item.state),
    ].filter(Boolean).join(", ");

    return [{
      id: guid,
      title,
      link,
      location,
      company,
      description: text(item.description),
      type: text(item.type),
      pubDate: text(item.pubDate) || undefined,
    }];
  });
}
