import * as fs from "node:fs";
import { glob } from 'glob';

import { PromptTemplate } from "@langchain/core/prompts";
import { ChatOllama } from "@langchain/ollama";
import * as https from "./https";

const MODEL = "qwen3:8b";

interface Content {
    type: string;
    text: string;
}

const ollamaLlm = new ChatOllama({
    model: MODEL,
    temperature: 1.0
});

const postHandler = new https.Handler();
postHandler.getInfo().then(async () => {
    const files = glob.sync(`papero/**/*.json`);
    const indexes = Array.from({ length: 5 }, () => Math.floor(Math.random() * files.length));
    const posts: string[] = [];

    for (const index of indexes) {
        const file = files[index];
        console.log(`Processing file: ${file}`);
        const json = JSON.parse(fs.readFileSync(file, 'utf-8'));

        const text: string = (json.content as Content[])
            .filter(item => item.type === 'text')
            .map(item => item.text)
            .filter(item => item.length > 0)
            .join("\n\n");

        posts.push(text);
    }

    const promptTemplate = PromptTemplate.fromTemplate(`
Sto per mostrarti una serie di post scritti da me.

Il tuo compito è:
1. Leggere attentamente i miei testi.
2. Cogliere il mio stile, il mio modo di osservare il mondo, il tono, il ritmo e il vocabolario che uso.
3. Poi, scrivere un nuovo post, completamente originale, che sembri scritto da me.

Il nuovo post deve:
- essere coerente con il mio stile personale,
- trattare un tema che potrebbe emergere dai miei scritti (non serve che sia lo stesso),
- avere un tono umano, autentico e riflessivo,
- evitare frasi artificiali, didascaliche o troppo spiegate,
- risultare naturale, come se fosse nato da uno stato d'animo o da un'esperienza vissuta.

---

### Ecco i miei post:

{context}

---

Ora scrivi un nuovo post, come se fossi io.
    `);

    const prompt = await promptTemplate.format({
        context: posts.join("\n---\n")
    })
    console.log(prompt);

    const response = await ollamaLlm.invoke(prompt);
    const content = response.content as string;
    console.log(`Generated post:\n${content}`);
    await postHandler.post(content.slice(content.indexOf("</think>") + 8).trim());
});

