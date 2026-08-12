#import "LPLyricFetcher.h"

@implementation LPLyricFetcher

- (void)fetchLyricsForTitle:(NSString *)title artist:(NSString *)artist provider:(LPLyricProvider)provider completion:(void(^)(LPLyricDocument * _Nullable document, NSError * _Nullable error))completion {
    if (title.length == 0) {
        completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Missing title"}]);
        return;
    }

    NSString *keyword = [NSString stringWithFormat:@"%@ %@", title ?: @"", artist ?: @""];
    NSString *encodedKeyword = [keyword stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *searchURLString = [NSString stringWithFormat:@"https://music.163.com/api/search/get/web?type=1&limit=1&s=%@", encodedKeyword];

    NSURL *searchURL = [NSURL URLWithString:searchURLString];
    if (!searchURL) {
        completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Invalid search URL"}]);
        return;
    }

    NSURLSessionDataTask *searchTask = [[NSURLSession sharedSession] dataTaskWithURL:searchURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data) {
            completion(nil, error ?: [NSError errorWithDomain:@"LPLyricFetcher" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Search failed"}]);
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *songs = json[@"result"][@"songs"];
        NSDictionary *song = songs.firstObject;
        NSNumber *songID = song[@"id"];
        if (!songID) {
            completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Lyric source not found"}]);
            return;
        }

        NSString *lyricURLString = [NSString stringWithFormat:@"https://music.163.com/api/song/lyric?os=ios&id=%@&lv=-1&kv=-1&tv=-1", songID.stringValue];
        NSURL *lyricURL = [NSURL URLWithString:lyricURLString];
        if (!lyricURL) {
            completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Invalid lyric URL"}]);
            return;
        }

        NSURLSessionDataTask *lyricTask = [[NSURLSession sharedSession] dataTaskWithURL:lyricURL completionHandler:^(NSData * _Nullable lyricData, NSURLResponse * _Nullable lyricResponse, NSError * _Nullable lyricError) {
            if (lyricError || !lyricData) {
                completion(nil, lyricError ?: [NSError errorWithDomain:@"LPLyricFetcher" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Lyric request failed"}]);
                return;
            }

            NSDictionary *lyricJSON = [NSJSONSerialization JSONObjectWithData:lyricData options:0 error:nil];
            NSString *lrc = lyricJSON[@"lrc"][@"lyric"];
            if (lrc.length == 0) {
                completion(nil, [NSError errorWithDomain:@"LPLyricFetcher" code:404 userInfo:@{NSLocalizedDescriptionKey: @"No lyric content"}]);
                return;
            }

            LPLyricDocument *document = [LPLyricDocument documentWithLRC:lrc];
            completion(document, nil);
        }];
        [lyricTask resume];
    }];
    [searchTask resume];
}

@end
