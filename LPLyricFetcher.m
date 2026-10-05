#import "LPLyricFetcher.h"

@implementation LPLyricFetcher

- (NSMutableURLRequest *)requestForURL:(NSURL *)url {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:12.0];
    request.HTTPMethod = @"GET";
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"https://music.163.com" forHTTPHeaderField:@"Referer"];
    [request setValue:@"application/json, text/plain, */*" forHTTPHeaderField:@"Accept"];
    return request;
}

- (void)fetchJSONWithRequest:(NSURLRequest *)request completion:(void(^)(NSDictionary * _Nullable json, NSError * _Nullable error))completion {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data) {
            completion(nil, error ?: [NSError errorWithDomain:@"LPLyricFetcher" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Request failed"}]);
            return;
        }

        NSInteger statusCode = 200;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            statusCode = ((NSHTTPURLResponse *)response).statusCode;
        }
        if (statusCode < 200 || statusCode >= 300) {
            completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:statusCode userInfo:@{NSLocalizedDescriptionKey: @"Unexpected response status"}]);
            return;
        }

        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![object isKindOfClass:[NSDictionary class]]) {
            completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Invalid JSON payload"}]);
            return;
        }

        completion((NSDictionary *)object, nil);
    }];
    [task resume];
}

- (NSArray<NSString *> *)searchKeywordsForTitle:(NSString *)title artist:(NSString *)artist {
    NSString *trimmedTitle = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *trimmedArtist = [(artist ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray<NSString *> *keywords = [NSMutableArray array];

    if (trimmedTitle.length > 0 && trimmedArtist.length > 0) {
        [keywords addObject:[NSString stringWithFormat:@"%@ %@", trimmedTitle, trimmedArtist]];
    }
    if (trimmedTitle.length > 0) {
        [keywords addObject:trimmedTitle];
    }

    return keywords.copy;
}

- (void)searchSongIDWithKeywords:(NSArray<NSString *> *)keywords index:(NSUInteger)index completion:(void(^)(NSNumber * _Nullable songID, NSError * _Nullable error))completion {
    if (index >= keywords.count) {
        completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Lyric source not found"}]);
        return;
    }

    NSString *keyword = keywords[index];
    NSString *encodedKeyword = [keyword stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *searchURLString = [NSString stringWithFormat:@"https://music.163.com/api/search/get/web?type=1&limit=8&s=%@", encodedKeyword ?: @""];
    NSURL *searchURL = [NSURL URLWithString:searchURLString];
    if (!searchURL) {
        completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Invalid search URL"}]);
        return;
    }

    NSMutableURLRequest *request = [self requestForURL:searchURL];
    [self fetchJSONWithRequest:request completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        if (error || !json) {
            completion(nil, error);
            return;
        }

        NSArray *songs = json[@"result"][@"songs"];
        NSNumber *songID = nil;
        if ([songs isKindOfClass:[NSArray class]]) {
            for (NSDictionary *song in songs) {
                if (![song isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSNumber *currentID = song[@"id"];
                if ([currentID isKindOfClass:[NSNumber class]]) {
                    songID = currentID;
                    break;
                }
            }
        }

        if (songID) {
            completion(songID, nil);
            return;
        }

        [self searchSongIDWithKeywords:keywords index:index + 1 completion:completion];
    }];
}

- (void)fetchLyricsForTitle:(NSString *)title artist:(NSString *)artist provider:(__unused LPLyricProvider)provider completion:(void(^)(LPLyricDocument * _Nullable document, NSError * _Nullable error))completion {
    if (title.length == 0) {
        completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Missing title"}]);
        return;
    }

    NSArray<NSString *> *keywords = [self searchKeywordsForTitle:title artist:artist];
    if (keywords.count == 0) {
        completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Missing keyword"}]);
        return;
    }

    [self searchSongIDWithKeywords:keywords index:0 completion:^(NSNumber * _Nullable songID, NSError * _Nullable searchError) {
        if (!songID) {
            completion(nil, searchError ?: [NSError errorWithDomain:@"LPLyricFetcher" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Lyric source not found"}]);
            return;
        }

        NSString *lyricURLString = [NSString stringWithFormat:@"https://music.163.com/api/song/lyric?os=ios&id=%@&lv=-1&kv=-1&tv=-1", songID.stringValue];
        NSURL *lyricURL = [NSURL URLWithString:lyricURLString];
        if (!lyricURL) {
            completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Invalid lyric URL"}]);
            return;
        }

        NSMutableURLRequest *lyricRequest = [self requestForURL:lyricURL];
        [self fetchJSONWithRequest:lyricRequest completion:^(NSDictionary * _Nullable lyricJSON, NSError * _Nullable lyricError) {
            if (lyricError || !lyricJSON) {
                completion(nil, lyricError ?: [NSError errorWithDomain:@"LPLyricFetcher" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Lyric request failed"}]);
                return;
            }

            NSString *lrc = lyricJSON[@"lrc"][@"lyric"];
            if (![lrc isKindOfClass:[NSString class]] || lrc.length == 0) {
                completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:404 userInfo:@{NSLocalizedDescriptionKey: @"No lyric content"}]);
                return;
            }

            LPLyricDocument *document = [LPLyricDocument documentWithLRC:lrc];
            completion(document, nil);
        }];
    }];
}

@end
