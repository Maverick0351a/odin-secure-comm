from prometheus_client import Counter

requests_total = Counter("odin_gateway_requests_total", "Gateway requests", ["route"])  
