export interface Blog {
    followers: number;
    name: string;
    description: string;
    posts: number;
    title: string;
    updated: number;
    url: string;
}

export interface BlogObject {
    blog: Blog;
}

export interface Content {
    type: string;
    text: string;
}

export interface Post {
    [key: string]: unknown;
    id_string: string;
    timestamp: number;
    asking_name?: string;
    tags: string[];
    content: Content[];
}

export interface Posts {
    total_posts: number;
    posts: Post[];
}

export interface Response<T> {
    meta: {
        status: number;
        msg: string;
    };
    response: T;
}
