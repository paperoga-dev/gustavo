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
    formatting?: [{
        [key: string]: unknown;
    }];
}

export interface Post {
    [key: string]: unknown;
    post_url: string;
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
