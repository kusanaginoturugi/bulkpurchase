const UPSTREAM = "https://bulkpurchase-worker.myouougoma.workers.dev";

export default {
  async fetch(request: Request): Promise<Response> {
    const incoming = new URL(request.url);
    const upstream = new URL(`${incoming.pathname}${incoming.search}`, UPSTREAM);
    const headers = new Headers(request.headers);
    // 本体WorkerがAuthentikの登録済み戻り先を使えるようにする。
    headers.set("X-Bulkpurchase-Host", "bulkpurchase.showway.biz");

    const init: RequestInit = {
      method: request.method,
      headers,
      redirect: "manual"
    };
    if (request.method !== "GET" && request.method !== "HEAD") init.body = request.body;

    return fetch(new Request(upstream, init));
  }
};
