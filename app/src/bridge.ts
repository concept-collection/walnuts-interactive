// Bridge to the numbl/MATLAB `uihtml` host. The host calls a global
// `setup(htmlComponent)` once the page loads; we expose small subscribe/send
// helpers so React components don't race that callback (latest Data is buffered,
// and host-event listeners attach whenever the component becomes available).

interface HtmlComponent {
  Data: unknown;
  addEventListener(name: string, fn: (e: { Data?: unknown }) => void): void;
  sendEventToMATLAB(name: string, data: unknown): void;
}

type DataListener = (data: unknown) => void;
type EventListener = (data: unknown) => void;

let htmlComponent: HtmlComponent | null = null;
let latestData: unknown = undefined;
const dataListeners = new Set<DataListener>();
const eventListeners = new Map<string, Set<EventListener>>();
const attachedNames = new Set<string>();

function deliverData(d: unknown): void {
  latestData = d;
  dataListeners.forEach(fn => fn(d));
}

/** Attach a single host listener for `name` that fans out to our listener set. */
function attach(name: string): void {
  if (!htmlComponent || attachedNames.has(name)) return;
  attachedNames.add(name);
  htmlComponent.addEventListener(name, e => {
    const fns = eventListeners.get(name);
    if (fns) fns.forEach(fn => fn(e?.Data));
  });
}

// Register the global the host calls after the page loads.
(window as unknown as { setup: (hc: HtmlComponent) => void }).setup = hc => {
  htmlComponent = hc;
  hc.addEventListener("DataChanged", () => deliverData(hc.Data));
  for (const name of eventListeners.keys()) attach(name);
  if (hc.Data != null) deliverData(hc.Data);
};

/** Subscribe to the `Data` channel (script → page). Fires immediately with the
 *  latest data if it has already arrived. */
export function onData(fn: DataListener): () => void {
  dataListeners.add(fn);
  if (latestData !== undefined) fn(latestData);
  return () => {
    dataListeners.delete(fn);
  };
}

/** Subscribe to a named host event (from MATLAB `sendEventToHTMLSource`). */
export function onHostEvent(name: string, fn: EventListener): () => void {
  let set = eventListeners.get(name);
  if (!set) {
    set = new Set();
    eventListeners.set(name, set);
  }
  set.add(fn);
  attach(name);
  return () => {
    set!.delete(fn);
  };
}

/** Send an event back to the interpreter (page → script). */
export function sendToMATLAB(name: string, data: unknown): void {
  htmlComponent?.sendEventToMATLAB(name, data);
}
