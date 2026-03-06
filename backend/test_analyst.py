import asyncio
from agents.scenario_analyst import run_scenario_analyst

async def main():
    try:
        res = await run_scenario_analyst("A massive cyber attack", "test_session_1")
        print("SUCCESS:", res.get("crisis_title"))
    except Exception as e:
        import traceback
        traceback.print_exc()

asyncio.run(main())
