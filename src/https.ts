import * as fs from "node:fs";
import * as https from "node:https";
import * as querystring from "node:querystring";
import * as timers from "node:timers";

interface Token {
    access_token: string;
    token_type: string;
    requested: number;
    expires_in: number;
    refresh_token: string;
    scope: string;
}

export class Handler {
    private static readonly MAX_RETRIES = 5;
    private readonly tokenPath = "token.json";
    private token?: Token;

    public async getInfo(): Promise<void> {
        return this.doRequest(
            {
                hostname: "api.tumblr.com",
                method: "GET",
                port: 443,
                path: "/v2/user/info"
            },
            Handler.MAX_RETRIES
        )
    }

    public async post(blog: string, content: object): Promise<void> {
        return this.doRequest(
            {
                hostname: "api.tumblr.com",
                method: "POST",
                port: 443,
                path: `/v2/blog/${blog}/posts`,
            },
            Handler.MAX_RETRIES,
            content
        );
    }

    private async getToken(): Promise<Token> {
        try {
            if (!this.token) {
                this.token = JSON.parse(fs.readFileSync(this.tokenPath, { encoding: "utf-8" })) as Token;
            }

            if (this.token.requested + this.token.expires_in < Math.trunc(Date.now() / 1000) - 30) {
                console.warn("\tToken expired, refreshing...");
            } else {
                return this.token;
            }
        } catch (ignoreErr) {

        }

        /* eslint-disable camelcase */
        const tokenData = querystring.stringify({
            ...{
                client_id: process.env.CLIENT_ID,
                client_secret: process.env.CLIENT_SECRET,
                grant_type: this.token ? "refresh_token" : "authorization_code"
            },
            ...this.token
                ? { refresh_token: this.token.refresh_token }
                : {
                    code: process.env.CODE,
                    redirect_uri: process.env.REDIRECT_URI
                }
        });
        /* eslint-enable camelcase */

        const authData = await new Promise<string>((resolve, reject) => {
            let resData = "";

            const req = https.request({
                headers: {
                    "Content-Length": Buffer.byteLength(tokenData),
                    "Content-Type": "application/x-www-form-urlencoded",
                    "User-Agent": `Gustavo/1.0.0`
                },
                hostname: "api.tumblr.com",
                method: "POST",
                path: "/v2/oauth2/token",
                port: 443
            }, (res) => {
                switch (res.statusCode) {
                    case 200:
                        res.setEncoding("utf8");

                        res.on("data", (chunk) => {
                            resData += chunk;
                        });

                        res.on("end", () => {
                            if (resData === "") {
                                reject(new Error("no data received"));
                                return;
                            }

                            resolve(resData);
                        });
                        break;

                    default:
                        reject(new Error(`response error, ${res.statusCode}`));
                        break;
                }
            });

            req.setTimeout(10000);

            req.on("error", (err) => {
                reject(new Error(`request error, ${err.toString()}`));
            });

            req.on("timeout", () => {
                req.destroy();
                reject(new Error(`timeout`));
            });

            req.write(tokenData);
            req.end();
        });

        this.token = {
            ...(JSON.parse(authData) as Omit<Token, "requested">),
            requested: Math.trunc(Date.now() / 1000)
        };
        fs.writeFileSync(this.tokenPath, JSON.stringify(this.token), { encoding: "utf-8" });
        return this.token;
    }

    private async doRequest(
        options: https.RequestOptions, failures: number, body?: object
    ): Promise<void> {
        if (failures === 0) {
            throw new Error("Request failed");
        }

        const jsonBody = JSON.stringify(body);

        const token = await this.getToken();

        return new Promise<void>((resolve) => {
            const retry = (msg: string): void => {
                console.error(`\t${msg}, retrying in 5 seconds ...`);
                timers.setTimeout(() => {
                    resolve(this.doRequest(options, failures - 1, body));
                }, 5000);
            };

            const req = https.request({
                headers: body ? {
                    Authorization: `Bearer ${token.access_token}`,
                    "Content-Length": Buffer.byteLength(jsonBody),
                    "Content-Type": "application/json",
                    "User-Agent": `Gustavo/1.0.0`
                } : {
                    Authorization: `Bearer ${token.access_token}`,
                    "User-Agent": `Gustavo/1.0.0`
                },
                ...options
            }, (res) => {
                switch (res.statusCode) {
                    case 200:
                        res.setEncoding("utf8");
                        res.on("data", () => { });
                        res.on("end", () => {
                            if (body) {
                                timers.setTimeout(() => {
                                    resolve(this.doRequest(options, failures - 1, body));
                                }, 10000);
                            } else {
                                resolve();
                            }
                        });
                        break;

                    case 201:
                        res.setEncoding("utf8");
                        res.on("data", () => { });
                        res.on("end", () => {
                            resolve();
                        });
                        break;

                    case 401:
                        timers.setTimeout(() => {
                            resolve(this.doRequest(options, failures - 1, body));
                        }, 10000);
                        break;

                    default:
                        retry(`response error, ${res.statusCode}`);
                        break;
                }
            });

            req.setTimeout(10000);

            req.on("error", (err) => {
                retry(`request error, ${err.toString()}`);
            });

            req.on("timeout", () => {
                req.destroy();
                retry("timeout");
            });

            if (body) {
                req.write(jsonBody);
            }
            req.end();
        });
    }
}
