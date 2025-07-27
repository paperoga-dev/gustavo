import * as fs from "node:fs";
import { glob } from 'glob';

import { PromptTemplate } from "@langchain/core/prompts";
import { ChatOllama } from "@langchain/ollama";
import * as https from "./https.js";

interface Content {
    type: string;
    text: string;
}

export async function doPost(folder: string, blog: string, model: ChatOllama, contextSize: number, minSize: number, tumblrHandler?: https.Handler): Promise<void> {
    if (!fs.existsSync(folder)) {
        throw new Error(`Blog directory does not exist: ${folder}`);
    }

    if (!fs.lstatSync(folder).isDirectory()) {
        throw new Error(`Path is not a directory: ${folder}`);
    }

    const files = glob.sync(`${folder}/**/*.json`);

    if (files.length === 0) {
        throw new Error(`No JSON files found in the directory: ${folder}`);
    }

    const posts: string[] = [];
    while (posts.length < contextSize && files.length > 0) {
        const index = Math.floor(Math.random() * files.length);
        const [ file ] = files.splice(index, 1);

        const json = JSON.parse(fs.readFileSync(file!, { encoding: "utf-8" })) as {
            content?: Content[];
            [key: string]: unknown;
        };

        if (json.content === undefined || json.content.length === 0) {
            continue;
        }

        const text: string = (json.content as Content[])
            .filter(item => item.type === 'text')
            .map(item => item.text)
            .filter(item => item.length > 0)
            .join("\n\n");

        if (text.length > minSize) {
            posts.push(text);
        }
    }

    if (files.length === 0 && posts.length < contextSize) {
        throw new Error(`Not enough posts found in the directory: ${folder}`);
    }

    const promptTemplate = PromptTemplate.fromTemplate(
`Sto per mostrarti una serie di post scritti da me.

Il tuo compito è:
1. Leggere attentamente i miei testi.
2. Cogliere il mio stile, il mio modo di osservare il mondo, il tono, il ritmo e il vocabolario che uso.
3. Poi, scrivere un nuovo post, completamente originale, che sembri scritto da me.

Il nuovo post deve:
- essere contenuto tra i tag <post> e </post>,
- essere coerente con il mio stile personale,
- trattare un tema che potrebbe emergere dai miei scritti (non serve che sia lo stesso),
- avere un tono umano, autentico e riflessivo,
- evitare frasi artificiali, didascaliche o troppo spiegate,
- risultare naturale, come se fosse nato da uno stato d'animo o da un'esperienza vissuta,
- avere comunque un sottotesto ironico e leggero.

---

### Ecco i miei post:

{context}

---

Ora scrivi un nuovo post, come se fossi io.
`);

    const prompt = await promptTemplate.format({
        context: posts.join("\n---\n")
    })
    process.stdout.write(`Prompt:${prompt}\n\n`);

    let tries = 5;
    while (tries--) {
        const response = await model.invoke(prompt);
        const llmOutput = response.content as string;
        process.stdout.write(`LLM output:\n${llmOutput}\n\n`);

        const llmPost = llmOutput.match(/<post>(.*?)<\/post>/s);

        if (!llmPost) {
            continue;
        }

        const tumblrPost = llmPost[1]!
            .trim()
            .split("\n")
            .map(line => line.trim())
            .filter(line => line.length > 0)
            .map(line => ({
                type: "text",
                text: line
            }) as Content);

        const postObj = {
            content: tumblrPost
        };

        process.stdout.write(`Tumblr post:\n${JSON.stringify(postObj, undefined, 2)}\n\n`);

        await tumblrHandler?.post(blog, postObj);
        break;
    }
}
