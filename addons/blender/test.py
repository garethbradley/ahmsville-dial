import asyncio
import websockets

async def readData(websocket):
    message = await websocket.recv()
    print(f"{message}")

async def hello():
    uri = "ws://localhost:23425/ws"

    async with websockets.connect(uri, ping_interval=None, ping_timeout=5) as websocket:
        while True:
            try:
                loop = asyncio.get_event_loop()
                # data = await loop.run_in_executor(None, 
                #                             lambda:get_data(username))
                # await websocket.send(json.dumps(data))
                # await asyncio.sleep(30)
                await asyncio.wait_for(readData(websocket), timeout=1.0)
            except websockets.ConnectionClosed as e:
                print(f'Terminated', e)
                continue
            except TimeoutError as e:
                print('timeout!')
                continue
            except Exception as e:
                print(f'Unhandled Exception', e)
                        


if __name__ == "__main__":
    asyncio.run(hello())

    