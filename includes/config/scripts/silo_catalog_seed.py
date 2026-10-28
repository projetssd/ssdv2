#!/usr/bin/env python3
"""Génère un seed de catalogue Silo à partir de l'arborescence sffs."""

import argparse
import gzip
import json
import os
import re
import sys
from datetime import datetime, timezone

VIDEO_EXTENSIONS = {".avi", ".m4v", ".mkv", ".mov", ".mp4", ".ts", ".webm", ".wmv"}
TMDB_SUFFIX = re.compile(r"\s*\{tmdb-(\d+)\}\s*$")
YEAR_SUFFIX = re.compile(r"\s*\((\d{4})\)\s*$")
SEASON_DIR = re.compile(r"(?i)^season[\s._-]*(\d{1,2})$")
EPISODE_SXXEXX = re.compile(r"(?i)(?:^|[^a-z0-9])s(\d{1,2})[\s._-]*e(\d{1,3})(?:[^0-9]|$)")
EPISODE_XXxXX = re.compile(r"(?i)(?:^|[^0-9])(\d{1,2})x(\d{1,3})(?:[^0-9]|$)")
RESOLUTION = re.compile(r"(?i)(2160|1080|720|480)p?")
RESOLUTION_RANK = {"1080": 0, "720": 1, "2160": 2, "480": 3}


def now_utc():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def split_title_year(name):
    base = TMDB_SUFFIX.sub("", name).strip()
    match = YEAR_SUFFIX.search(base)
    if match:
        return base[: match.start()].strip(), int(match.group(1))
    return base, 0


def resolution_rank(name):
    match = RESOLUTION.search(name)
    if not match:
        return RESOLUTION_RANK.get("unknown", 4)
    return RESOLUTION_RANK.get(match.group(1), 4)


def is_video(path):
    return os.path.splitext(path)[1].lower() in VIDEO_EXTENSIONS


def choose_video(paths):
    if not paths:
        return None
    return min(
        paths,
        key=lambda path: (resolution_rank(os.path.basename(path)), -os.path.getsize(path)),
    )


def video_paths(root):
    found = []
    for current, _, files in os.walk(root):
        for name in files:
            path = os.path.join(current, name)
            if is_video(path):
                found.append(path)
    return found


def item_base(content_id, item_type, title, year, tmdb, stamp, season_count=None):
    item = {
        "content_id": content_id,
        "type": item_type,
        "title": title,
        "sort_title": title.lower(),
        "original_title": title,
        "year": year,
        "genres": [],
        "content_rating": "",
        "runtime": 0,
        "overview": "",
        "tagline": "",
        "imdb_id": "",
        "tmdb_id": str(tmdb),
        "tvdb_id": "",
        "poster_path": "",
        "backdrop_path": "",
        "logo_path": "",
        "studios": [],
        "networks": [],
        "countries": [],
        "keywords": [],
        "original_language": "",
        "matched_at": stamp,
        "last_refreshed": stamp,
        "refresh_failures": 0,
        "locked_fields": [],
        "status": "matched",
        "created_at": stamp,
        "updated_at": stamp,
    }
    if season_count:
        item["season_count"] = season_count
    return item


def file_record(content_id, media_folder_id, path, stamp, episode_id="", season=0, episode=0):
    return {
        "content_id": content_id,
        "episode_id": episode_id,
        "season_number": season,
        "episode_number": episode,
        "media_folder_id": media_folder_id,
        "file_path": path,
        "file_size": os.path.getsize(path),
        "file_hash": "",
        "codec_video": "",
        "codec_audio": "",
        "resolution": "",
        "audio_channels": 0,
        "hdr": False,
        "container": os.path.splitext(path)[1].lstrip(".").lower(),
        "duration": 0,
        "bitrate": 0,
        "video_tracks": [],
        "audio_tracks": [],
        "subtitle_tracks": [],
        "external_subtitles": [],
        "probe_source": "",
        "created_at": stamp,
        "updated_at": stamp,
    }


def scan_movies(root, stamp, excluded, limit):
    items, files, links = [], [], []
    if not os.path.isdir(root):
        return items, files, links
    for entry in sorted(os.scandir(root), key=lambda e: e.name):
        if len(items) >= limit or not entry.is_dir(follow_symlinks=False):
            continue
        match = TMDB_SUFFIX.search(entry.name)
        if not match:
            continue
        tmdb = int(match.group(1))
        content_id = f"movie-tmdb-{tmdb}"
        if content_id in excluded:
            continue
        chosen = choose_video(video_paths(entry.path))
        if not chosen:
            continue
        title, year = split_title_year(entry.name)
        items.append(item_base(content_id, "movie", title, year, tmdb, stamp))
        files.append(file_record(content_id, 1, chosen, stamp))
        links.append({"content_id": content_id, "media_folder_id": 1, "first_seen_at": stamp})
    return items, files, links


def episode_numbers(path, relative):
    name = os.path.basename(path)
    match = EPISODE_SXXEXX.search(name) or EPISODE_XXxXX.search(name)
    if not match:
        return None
    season, episode = int(match.group(1)), int(match.group(2))
    for part in reversed(os.path.dirname(relative).split(os.sep)):
        season_dir = SEASON_DIR.match(part)
        if season_dir:
            return int(season_dir.group(1)), episode
    return season, episode


def scan_series(root, stamp, excluded, limit):
    items, files, links, seasons, episodes = [], [], [], [], []
    if not os.path.isdir(root):
        return items, files, links, seasons, episodes
    for entry in sorted(os.scandir(root), key=lambda e: e.name):
        if len(items) >= limit or not entry.is_dir(follow_symlinks=False):
            continue
        match = TMDB_SUFFIX.search(entry.name)
        if not match:
            continue
        tmdb = int(match.group(1))
        content_id = f"series-tmdb-{tmdb}"
        if content_id in excluded:
            continue
        by_episode = {}
        for path in video_paths(entry.path):
            relative = os.path.relpath(path, entry.path)
            numbers = episode_numbers(path, relative)
            if not numbers:
                continue
            by_episode.setdefault(numbers, []).append(path)
        if not by_episode:
            continue
        title, year = split_title_year(entry.name)
        max_season = max(season for season, _ in by_episode)
        items.append(item_base(content_id, "series", title, year, tmdb, stamp, max_season))
        for season in sorted({season for season, _ in by_episode}):
            season_id = f"season-tmdb-{tmdb}-{season}"
            seasons.append(
                {
                    "content_id": season_id,
                    "series_id": content_id,
                    "season_number": season,
                    "title": f"Season {season:02d}",
                    "overview": "",
                    "poster_path": "",
                    "poster_thumbhash": "",
                    "metadata_s3_path": "",
                    "metadata_etag": "",
                    "created_at": stamp,
                    "updated_at": stamp,
                }
            )
        for (season, episode), paths in sorted(by_episode.items()):
            chosen = choose_video(paths)
            if not chosen:
                continue
            episode_id = f"episode-tmdb-{tmdb}-{season}-{episode}"
            episodes.append(
                {
                    "content_id": episode_id,
                    "series_id": content_id,
                    "season_id": f"season-tmdb-{tmdb}-{season}",
                    "season_number": season,
                    "episode_number": episode,
                    "title": f"S{season:02d}E{episode:02d}",
                    "overview": "",
                    "runtime": 0,
                    "still_path": "",
                    "still_thumbhash": "",
                    "metadata_s3_path": "",
                    "metadata_etag": "",
                    "created_at": stamp,
                    "updated_at": stamp,
                }
            )
            files.append(file_record(content_id, 2, chosen, stamp, episode_id, season, episode))
        links.append({"content_id": content_id, "media_folder_id": 2, "first_seen_at": stamp})
    return items, files, links, seasons, episodes


def load_excluded(path):
    if not path:
        return set()
    with open(path, encoding="utf-8") as handle:
        return {line.strip() for line in handle if line.strip()}


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--films-dir", default="/mnt/sffs/films")
    parser.add_argument("--series-dir", default="/mnt/sffs/series")
    parser.add_argument("--output", required=True)
    parser.add_argument("--exclude-file")
    parser.add_argument("--max-movies", type=int, default=0)
    parser.add_argument("--max-series", type=int, default=0)
    parser.add_argument("--schema-version", type=int, default=0)
    return parser.parse_args()


def main():
    args = parse_args()
    stamp = now_utc()
    excluded = load_excluded(args.exclude_file)
    movie_limit = args.max_movies if args.max_movies > 0 else sys.maxsize
    series_limit = args.max_series if args.max_series > 0 else sys.maxsize

    movies, movie_files, movie_links = scan_movies(args.films_dir, stamp, excluded, movie_limit)
    series, series_files, series_links, seasons, episodes = scan_series(
        args.series_dir, stamp, excluded, series_limit
    )
    if not movies and not series:
        raise SystemExit("aucun média trouvé dans les dossiers sffs")

    libraries = []
    if movies:
        libraries.append(
            {
                "exported_id": 1,
                "paths": [args.films_dir],
                "type": "movies",
                "name": "Films",
                "enabled": True,
                "last_scanned_at": stamp,
                "allow_empty_cleanup_once": False,
            }
        )
    if series:
        libraries.append(
            {
                "exported_id": 2,
                "paths": [args.series_dir],
                "type": "series",
                "name": "Séries",
                "enabled": True,
                "last_scanned_at": stamp,
                "allow_empty_cleanup_once": False,
            }
        )

    bundle = {
        "manifest": {
            "format_version": 2,
            "exported_at": stamp,
            "schema_version": args.schema_version,
        },
        "libraries": libraries,
        "items": movies + series,
        "people": [],
        "embeddings": [],
        "seasons": seasons,
        "episodes": episodes,
        "files": movie_files + series_files,
        "library_links": movie_links + series_links,
    }
    with gzip.open(args.output, "wt", encoding="utf-8") as handle:
        json.dump(bundle, handle, ensure_ascii=False, separators=(",", ":"))
    print(
        json.dumps(
            {
                "items": len(bundle["items"]),
                "movies": len(movies),
                "series": len(series),
                "files": len(bundle["files"]),
                "seasons": len(seasons),
                "episodes": len(episodes),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
