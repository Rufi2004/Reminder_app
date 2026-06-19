import asyncio
import edge_tts


async def generate_audio(text, output_file):
    communicate = edge_tts.Communicate(
        text=text,
        voice="en-US-JennyNeural"
    )

    await communicate.save(output_file)


def create_audio(text, output_file):
    asyncio.run(generate_audio(text, output_file))