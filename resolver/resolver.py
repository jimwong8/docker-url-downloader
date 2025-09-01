from fastapi import FastAPI
from pydantic import BaseModel
from playwright.async_api import async_playwright
import asyncio
import time
from concurrent.futures import ThreadPoolExecutor

CACHE_TTL = 300
MAX_WORKERS = 4

cache = {}
executor = ThreadPoolExecutor(max_workers=MAX_WORKERS)

app = FastAPI()

class Req(BaseModel):
    url: str

async def parse_with_playwright(url: str):
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto(url, wait_until="networkidle")
        final_url = await page.get_attribute("#download", "href")
        headers = {
            "User-Agent": await page.evaluate("() => navigator.userAgent"),
            "Referer": url
        }
        await browser.close()
    return {"url": final_url, "headers": headers}

async def get_or_resolve(url: str):
    now = time.time()
    if url in cache:
        ts, result = cache[url]
        if now - ts < CACHE_TTL:
            return result
    result = await parse_with_playwright(url)
    cache[url] = (now, result)
    return result

@app.post("/resolve")
async def resolve(req: Req):
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        executor,
        lambda: asyncio.run(get_or_resolve(req.url))
    )
    return result