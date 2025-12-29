#!/usr/bin/env python3
"""
Ultra Fast Traefik Configuration Scanner
快速且全面的 Traefik 配置搜索工具
参考 UltraFastScanner 架构，专门针对 Traefik 配置优化
"""

import os
import subprocess
import shutil
import threading
import queue
import time
import json
import logging
import re
from pathlib import Path
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import defaultdict
import csv
import gc
from github import Github
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


class TraefikConfigFilter:
    """Traefik 配置过滤器"""
    
    FILTERS = [
        {
            'name': 'forwardedHeaders.insecure (YAML)',
            'keyword': 'forwardedHeaders',
            'regex': r'forwardedHeaders.*insecure.*true',
            'risk_level': 'high',
            'file_extensions': ['.yml', '.yaml']
        },
        {
            'name': 'forwardedHeaders.insecure (TOML)',
            'keyword': 'forwardedHeaders',
            'regex': r'forwardedHeaders.*insecure.*=.*true',
            'risk_level': 'high',
            'file_extensions': ['.toml']
        },
        {
            'name': 'trustForwardHeader (YAML)',
            'keyword': 'trustForwardHeader',
            'regex': r'trustForwardHeader.*true',
            'risk_level': 'medium',
            'file_extensions': ['.yml', '.yaml']
        },
        {
            'name': 'trustForwardHeader (TOML)',
            'keyword': 'trustForwardHeader',
            'regex': r'trustForwardHeader.*=.*true',
            'risk_level': 'medium',
            'file_extensions': ['.toml']
        },
        {
            'name': 'traefik docker-compose',
            'keyword': 'traefik',
            'regex': r'traefik.*forwardedHeaders',
            'risk_level': 'medium',
            'file_extensions': ['.yml', '.yaml']
        }
    ]
    
    @staticmethod
    def get_filters():
        return TraefikConfigFilter.FILTERS


class UltraFastTraefikScanner:
    """Ultra Fast Traefik 配置扫描器"""
    
    def __init__(self, config_path='config.json', config_override=None):
        if config_override:
            self.config = config_override
        else:
            self.config = self.load_config(config_path)
        
        # Setup output directory
        self.output_dir = Path('traefik_scan_results')
        self.output_dir.mkdir(exist_ok=True)
        
        # Setup logging
        self.logger = self.setup_logging()
        
        # Load GitHub tokens
        self.github_token = os.getenv('GITHUB_TOKEN')
        if not self.github_token:
            raise ValueError("Please set GITHUB_TOKEN in .env file")
        
        # Support multiple GitHub tokens
        self.github_tokens = []
        self.token_lock = threading.Lock()
        
        # Parse multiple tokens (comma-separated or newline-separated)
        if ',' in self.github_token:
            self.github_tokens = [token.strip() for token in self.github_token.split(',')]
        elif '\n' in self.github_token:
            self.github_tokens = [token.strip() for token in self.github_token.split('\n') if token.strip()]
        else:
            self.github_tokens = [self.github_token]
        
        self.logger.info(f"[GITHUB] Loaded {len(self.github_tokens)} GitHub tokens")
        
        # Initialize GitHub clients for each token
        self.github_clients = []
        for token in self.github_tokens:
            try:
                client = Github(token)
                rate_limit = client.get_rate_limit()
                self.github_clients.append({
                    'client': client,
                    'token': token,
                    'rate_limit': rate_limit,
                    'last_used': 0,
                    'error_count': 0
                })
                self.logger.info(f"[GITHUB] Token {token[:8]}... - Rate limit: {rate_limit.resources.core.remaining}/{rate_limit.resources.core.limit}")
            except Exception as e:
                self.logger.warning(f"[GITHUB] Failed to initialize token {token[:8]}...: {e}")
        
        if not self.github_clients:
            raise ValueError("No valid GitHub tokens found")
        
        # Load filters
        self.filters = TraefikConfigFilter.get_filters()
        
        # Setup result files
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        self.excel_file = str(self.output_dir / f'traefik_results_{timestamp}.xlsx')
        self.csv_file = str(self.output_dir / f'traefik_results_{timestamp}.csv')
        
        # Initialize result writer
        self.result_writer = TraefikResultWriter(self.csv_file, self.excel_file)
        
        # Statistics
        self.stats = TraefikSearchStats()
        
        # Thread-safe queues
        self.repo_queue = queue.Queue()
        self.result_queue = queue.Queue()
        self.stats_lock = threading.Lock()
        
        # Create temp directories
        self.temp_dirs = []
        self.temp_dir_index = 0
        self.temp_dir_lock = threading.Lock()
        self._init_temp_dirs()
        
        # Progress management
        self.progress = self.load_progress()
        self.processed_repos = set(self.progress.get('processed_repos', []))
        self.progress_lock = threading.Lock()
        
        # Memory management
        self.last_gc_time = time.time()
        self.gc_interval = 300  # 5 minutes
        
        # Performance monitoring
        self.start_time = None
        self.processed_count = 0
        
        # Cleanup management
        self.cleanup_enabled = True
        self.cleanup_after_each_repo = True
        self.max_retries = 2
        self.retry_delay = 0.5
        
        self.logger.info(f"[OK] Ultra Fast Traefik Scanner initialized with {len(self.temp_dirs)} temp directories")
        self.logger.info(f"[CONFIG] {self.config.get('concurrency', {}).get('max_workers', 8)} workers")
        self.logger.info(f"[PROGRESS] Loaded {len(self.processed_repos)} previously processed repositories")
        self.logger.info(f"[OUTPUT] Results will be saved to Excel: {self.excel_file} and CSV: {self.csv_file}")
    
    def get_best_github_client(self):
        """Get the best available GitHub client based on rate limits"""
        with self.token_lock:
            current_time = time.time()
            best_client = None
            best_score = -1
            
            for client_info in self.github_clients:
                # Skip clients with too many errors
                if client_info['error_count'] > 5:
                    continue
                
                # Calculate score
                remaining = client_info['rate_limit'].resources.core.remaining
                time_since_last = current_time - client_info['last_used']
                score = remaining + (time_since_last / 60)
                
                if score > best_score:
                    best_score = score
                    best_client = client_info
            
            if best_client:
                best_client['last_used'] = current_time
                return best_client['client']
            else:
                self.logger.warning("[GITHUB] No available tokens, waiting 60 seconds...")
                time.sleep(60)
                return self.get_best_github_client()
    
    def update_client_rate_limit(self, client, new_rate_limit):
        """Update rate limit for a specific client"""
        with self.token_lock:
            for client_info in self.github_clients:
                if client_info['client'] == client:
                    client_info['rate_limit'] = new_rate_limit
                    break
    
    def mark_client_error(self, client):
        """Mark a client as having an error"""
        with self.token_lock:
            for client_info in self.github_clients:
                if client_info['client'] == client:
                    client_info['error_count'] += 1
                    break
    
    def _init_temp_dirs(self):
        """Initialize multiple temp directories"""
        tmp_base = Path('tmp_traefik')
        if not tmp_base.exists():
            tmp_base.mkdir(exist_ok=True)
        
        num_dirs = self.config.get('concurrency', {}).get('max_workers', 8)
        
        existing_dirs = [d for d in tmp_base.iterdir() if d.is_dir() and d.name.startswith('traefik_scan_')]
        
        if len(existing_dirs) >= num_dirs:
            self.temp_dirs = existing_dirs[:num_dirs]
            self.logger.info(f"[INIT] Reusing {len(self.temp_dirs)} existing temp directories")
        else:
            self.temp_dirs = existing_dirs
            for i in range(len(existing_dirs), num_dirs):
                temp_dir = tmp_base / f'traefik_scan_{i}_{int(time.time())}'
                temp_dir.mkdir(exist_ok=True)
                self.temp_dirs.append(temp_dir)
            self.logger.info(f"[INIT] Created {num_dirs - len(existing_dirs)} new temp directories")
    
    def get_temp_dir(self):
        """Get next temp directory"""
        with self.temp_dir_lock:
            temp_dir = self.temp_dirs[self.temp_dir_index]
            self.temp_dir_index = (self.temp_dir_index + 1) % len(self.temp_dirs)
            return temp_dir
    
    def load_config(self, config_path):
        """Load configuration file"""
        default_config = {
            'concurrency': {
                'max_workers': 16,
                'clone_timeout': 300
            },
            'search': {
                'min_stars': 50,
                'time_window': {
                    'start_date': '2015-01-01',
                    'end_date': 'now',
                    'window_size_days': 30
                }
            },
            'logging': {
                'level': 'INFO',
                'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                'date_format': '%Y-%m-%d %H:%M:%S'
            }
        }
        
        if os.path.exists(config_path):
            with open(config_path, 'r', encoding='utf-8') as f:
                user_config = json.load(f)
                # Merge with defaults
                for key, value in default_config.items():
                    if key not in user_config:
                        user_config[key] = value
                    elif isinstance(value, dict):
                        user_config[key] = {**value, **user_config.get(key, {})}
                return user_config
        return default_config
    
    def load_progress(self):
        """Load progress information"""
        progress_file = self.output_dir / 'progress.json'
        if progress_file.exists():
            try:
                with open(progress_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    if 'processed_repos' not in data:
                        data['processed_repos'] = []
                    data.setdefault('current_date', self.config['search']['time_window']['end_date'])
                    data.setdefault('last_successful_search', None)
                    return data
            except Exception as e:
                self.logger.error(f"[ERROR] Error loading progress file: {str(e)}")
        return {
            'processed_repos': [],
            'current_date': self.config['search']['time_window']['end_date'],
            'last_successful_search': None
        }
    
    def save_progress(self):
        """Save progress information"""
        try:
            with self.progress_lock:
                progress_data = {
                    'processed_repos': list(self.processed_repos),
                    'current_date': self.progress.get('current_date'),
                    'last_successful_search': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
                
                progress_file = self.output_dir / 'progress.json'
                with open(progress_file, 'w', encoding='utf-8') as f:
                    json.dump(progress_data, f, indent=4)
        except Exception as e:
            self.logger.error(f"[ERROR] Error saving progress: {str(e)}")
    
    def setup_logging(self):
        """Setup logging"""
        log_config = self.config['logging']
        
        formatter = logging.Formatter(
            log_config['format'],
            datefmt=log_config['date_format']
        )
        
        log_file = self.output_dir / 'traefik_scanner.log'
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setFormatter(formatter)
        
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        
        logging.basicConfig(
            level=getattr(logging, log_config['level']),
            handlers=[file_handler, console_handler]
        )
        
        return logging.getLogger(__name__)
    
    def clone_repository_fast(self, repo_url, repo_name):
        """Fast clone repository"""
        temp_dir = self.get_temp_dir()
        repo_path = temp_dir / repo_name.replace('/', '_')
        
        if repo_path.exists():
            shutil.rmtree(repo_path, ignore_errors=True)
        
        try:
            cmd = [
                'git', 'clone',
                '--depth', '1',
                '--single-branch',
                '--no-tags',
                '--quiet',
                repo_url, str(repo_path)
            ]
            
            env = os.environ.copy()
            env['PYTHONIOENCODING'] = 'utf-8'
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='ignore',
                timeout=self.config.get('concurrency', {}).get('clone_timeout', 300),
                env=env
            )
            
            if result.returncode == 0:
                self.logger.debug(f"[OK] Successfully cloned {repo_name}")
                return repo_path
            else:
                self.logger.debug(f"[FAIL] Failed to clone {repo_name}: {result.stderr}")
                return None
        except subprocess.TimeoutExpired:
            self.logger.debug(f"[TIMEOUT] Timeout cloning {repo_name}")
            return None
        except Exception as e:
            self.logger.debug(f"[ERROR] Error cloning {repo_name}: {str(e)}")
            return None
    
    def scan_file_fast(self, file_path, filters):
        """Fast scan single file"""
        try:
            file_size = file_path.stat().st_size
            if file_size > 5 * 1024 * 1024:  # 5MB limit
                return []
            
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            matches = []
            
            for filter_item in filters:
                # Check file extension
                if file_path.suffix not in filter_item['file_extensions']:
                    continue
                
                hit = False
                
                # Keyword matching
                if filter_item['keyword'] and filter_item['keyword'] in content:
                    hit = True
                
                # Regex matching
                if filter_item.get('regex') and re.search(filter_item['regex'], content, re.IGNORECASE | re.MULTILINE):
                    hit = True
                
                if hit:
                    # Check if trustedIPs is configured (false positive reduction)
                    has_trusted_ips = re.search(r'trustedIPs|trustedIPs|trustedIPs', content, re.IGNORECASE)
                    
                    matches.append({
                        'filter_name': filter_item['name'],
                        'risk_level': filter_item['risk_level'],
                        'file_path': str(file_path),
                        'has_trusted_ips': bool(has_trusted_ips),
                        'content_preview': content[:500] + '...' if len(content) > 500 else content
                    })
            
            return matches
        except Exception as e:
            return []
    
    def scan_repository_fast(self, repo_path, filters):
        """Fast scan entire repository"""
        matches = []
        
        # Relevant file extensions
        relevant_extensions = {'.yml', '.yaml', '.toml', '.json', '.conf', '.cfg'}
        
        # Directories to skip
        skip_dirs = {
            '.git', 'node_modules', '__pycache__', 'venv', 'env',
            'build', 'dist', 'target', 'bin', 'obj', '.vs', '.idea',
            'vendor', 'bower_components', 'coverage', 'logs', 'tmp', 'temp', '.cache'
        }
        
        try:
            for root, dirs, files in os.walk(repo_path):
                # Filter directories
                dirs[:] = [d for d in dirs if not d.startswith('.') and d not in skip_dirs]
                
                for file in files:
                    file_path = Path(root) / file
                    
                    # Check file extension
                    if file_path.suffix not in relevant_extensions:
                        continue
                    
                    # Scan file
                    file_matches = self.scan_file_fast(file_path, filters)
                    if file_matches:
                        matches.extend(file_matches)
                        self.logger.info(f"[MATCH] Found matches in {file_path}")
            
            return matches
        except Exception as e:
            self.logger.debug(f"[ERROR] Error scanning repository {repo_path}: {str(e)}")
            return []
    
    def process_repository_worker(self, repo):
        """Worker thread processes single repository"""
        repo_name = repo.full_name
        repo_url = repo.clone_url
        repo_path = None
        
        # Check if already processed
        with self.progress_lock:
            if repo_name in self.processed_repos:
                return None
        
        try:
            # Clone repository
            repo_path = self.clone_repository_fast(repo_url, repo_name)
            if not repo_path:
                return None
            
            # Scan repository
            matches = self.scan_repository_fast(repo_path, self.filters)
            
            # Mark as processed
            with self.progress_lock:
                self.processed_repos.add(repo_name)
            
            # If matches found, record results
            if matches:
                # Group matches by filter
                matches_by_filter = defaultdict(list)
                for match in matches:
                    matches_by_filter[match['filter_name']].append(match)
                
                # Write to results
                written = self.result_writer.write(
                    repo_name,
                    repo.html_url,
                    repo.stargazers_count,
                    repo.created_at.year,
                    matches_by_filter
                )
                
                if written:
                    self.logger.info(f"[MATCH] {repo_name} - {len(matches)} matches found")
                    return {
                        'name': repo_name,
                        'url': repo.html_url,
                        'stars': repo.stargazers_count,
                        'year': repo.created_at.year,
                        'matches': matches,
                        'matches_count': len(matches)
                    }
            
            return None
        except Exception as e:
            self.logger.debug(f"[ERROR] Error processing {repo_name}: {str(e)}")
            return None
        finally:
            # Cleanup
            if repo_path and repo_path.exists():
                try:
                    if self.cleanup_after_each_repo:
                        shutil.rmtree(repo_path, ignore_errors=True)
                except Exception as e:
                    self.logger.debug(f"[CLEANUP] Failed to clean up {repo_name}: {e}")
    
    def batch_process_repositories(self, repositories, batch_size=10):
        """Process all repositories with rate limiting"""
        max_workers = self.config.get('concurrency', {}).get('max_workers', 16)
        
        self.logger.info(f"[PROCESS] Processing {len(repositories)} repositories with {max_workers} workers")
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [
                executor.submit(self.process_repository_worker, repo)
                for repo in repositories
            ]
            
            completed = 0
            last_save_time = time.time()
            
            for future in as_completed(futures):
                try:
                    result = future.result()
                    completed += 1
                    
                    if result:
                        with self.stats_lock:
                            self.stats.update(
                                repo_stars=result['stars'],
                                matches=len(result['matches'])
                            )
                    
                    # Progress reporting
                    if completed % 20 == 0:
                        elapsed = time.time() - self.start_time
                        speed = completed / elapsed * 60 if elapsed > 0 else 0
                        self.logger.info(f"[PROGRESS] {completed}/{len(repositories)} repositories processed ({speed:.1f} repos/min)")
                    
                    # Save progress every 10 minutes
                    current_time = time.time()
                    if current_time - last_save_time > 600:
                        self.save_progress()
                        self.result_writer.force_save()
                        last_save_time = current_time
                        self.logger.info(f"[SAVE] Progress saved - {len(self.processed_repos)} repositories processed")
                    
                    # Memory management
                    if completed % 100 == 0:
                        gc.collect()
                        
                except Exception as e:
                    completed += 1
                    self.logger.debug(f"[ERROR] Error in batch processing: {str(e)}")
            
            # Force save at end
            self.result_writer.force_save()
    
    def search_repositories_ultra_fast(self):
        """Ultra-fast search repositories using time window approach"""
        search_config = self.config['search']
        min_stars = search_config.get('min_stars', 0)
        window_size = search_config['time_window']['window_size_days']
        
        # Set time range, support resume from progress
        if self.progress.get('current_date'):
            try:
                if self.progress['current_date'] == 'now':
                    current_date = datetime.now()
                else:
                    current_date = datetime.strptime(self.progress['current_date'], '%Y-%m-%d')
                self.logger.info(f"[RESUME] Resuming from date: {current_date.strftime('%Y-%m-%d')}")
            except:
                current_date = datetime.now() if search_config['time_window']['end_date'] == 'now' else datetime.strptime(search_config['time_window']['end_date'], '%Y-%m-%d')
        else:
            current_date = datetime.now() if search_config['time_window']['end_date'] == 'now' else datetime.strptime(search_config['time_window']['end_date'], '%Y-%m-%d')
        
        end_date = datetime.strptime(search_config['time_window']['start_date'], '%Y-%m-%d')
        
        self.logger.info("[SEARCH] Starting repository search with time window approach...")
        
        # Initialize performance monitoring
        self.start_time = time.time()
        self.processed_count = 0
        
        try:
            while current_date > end_date:
                # Calculate current time window
                end_window = current_date
                start_window = current_date - timedelta(days=window_size)
                
                # Ensure we don't go before the start date
                if start_window < end_date:
                    start_window = end_date
                
                self.logger.info(f"[TIME] Searching time range: {start_window.strftime('%Y-%m-%d')} to {end_window.strftime('%Y-%m-%d')}")
                
                # Search for repositories with Traefik configuration using code search
                # Then filter by repository creation date
                # Using precise search queries to match actual configuration formats
                search_queries = [
                    # forwardedHeaders.insecure - Command line format (no value, just flag)
                    {
                        'name': 'forwardedHeaders.insecure (command line)',
                        'query': '"forwardedHeaders.insecure" language:yaml',
                        'file_extensions': ['.yml', '.yaml']
                    },
                    {
                        'name': 'forwardedHeaders.insecure (command line)',
                        'query': '"forwardedHeaders.insecure" language:toml',
                        'file_extensions': ['.toml']
                    },
                    # forwardedHeaders.insecure - YAML with value
                    {
                        'name': 'forwardedHeaders.insecure: true (YAML)',
                        'query': '"forwardedHeaders.insecure:" true language:yaml',
                        'file_extensions': ['.yml', '.yaml']
                    },
                    {
                        'name': 'forwardedHeaders.insecure = true (TOML)',
                        'query': '"forwardedHeaders.insecure" = true language:toml',
                        'file_extensions': ['.toml']
                    },
                    # forwardedHeaders nested format
                    {
                        'name': 'forwardedHeaders: { insecure: true } (YAML)',
                        'query': 'forwardedHeaders insecure true language:yaml',
                        'file_extensions': ['.yml', '.yaml']
                    },
                    # trustForwardHeader - Labels format (no space)
                    {
                        'name': 'trustForwardHeader=true (labels)',
                        'query': 'trustForwardHeader=true language:yaml',
                        'file_extensions': ['.yml', '.yaml']
                    },
                    # trustForwardHeader - YAML format (with space)
                    {
                        'name': 'trustForwardHeader: true (YAML)',
                        'query': '"trustForwardHeader:" true language:yaml',
                        'file_extensions': ['.yml', '.yaml']
                    },
                    # trustForwardHeader - TOML format
                    {
                        'name': 'trustForwardHeader = true (TOML)',
                        'query': 'trustForwardHeader = true language:toml',
                        'file_extensions': ['.toml']
                    }
                ]
                
                all_repos = set()
                
                # Search for code in this time window
                for search in search_queries:
                    try:
                        current_client = self.get_best_github_client()
                        code_results = current_client.search_code(
                            query=search['query'],
                            sort='indexed',
                            order='desc'
                        )
                        
                        total_results = code_results.totalCount
                        self.logger.info(f"[FOUND] Found {total_results} code results for '{search['name']}'")
                        
                        # Process results and filter by creation date
                        count = 0
                        filtered_count = 0
                        
                        for item in code_results:
                            # Check file extension
                            if not any(item.name.endswith(ext) for ext in search['file_extensions']):
                                continue
                            
                            repo = item.repository
                            repo_key = repo.full_name
                            
                            # Filter by repository creation date and stars
                            try:
                                full_repo = current_client.get_repo(repo.full_name)
                                repo_created = full_repo.created_at.date()
                                repo_stars = full_repo.stargazers_count
                                window_start = start_window.date()
                                window_end = end_window.date()
                                
                                # Check if repository was created in this time window and meets min_stars requirement
                                if window_start <= repo_created <= window_end and repo_stars >= min_stars:
                                    if repo_key not in all_repos:
                                        all_repos.add(repo_key)
                                        # Store repo object for processing
                                        all_repos.add(full_repo)
                                        filtered_count += 1
                                        
                                        if filtered_count % 50 == 0:
                                            self.logger.info(f"[PROGRESS] Found {filtered_count} repositories (≥{min_stars} stars) in time window for '{search['name']}'")
                                        
                                        # Rate limiting
                                        if filtered_count % 100 == 0:
                                            time.sleep(1)
                                
                                count += 1
                                
                                # Limit total code results to process
                                if count >= 2000:
                                    break
                                    
                            except Exception as e:
                                self.logger.debug(f"[ERROR] Failed to get repo {repo.full_name}: {e}")
                                continue
                        
                        self.logger.info(f"[COMPLETE] Processed {count} code results, found {filtered_count} repositories in time window for '{search['name']}'")
                        
                    except Exception as search_error:
                        self.logger.error(f"[ERROR] Search failed for '{search['name']}' in time range {start_window.strftime('%Y-%m-%d')} to {end_window.strftime('%Y-%m-%d')}: {search_error}")
                        
                        # Check if it's a rate limit error
                        if "403" in str(search_error) or "rate limit" in str(search_error).lower():
                            self.logger.warning("[RATE_LIMIT] GitHub API rate limit hit, waiting 60 seconds...")
                            time.sleep(60)
                        
                        # Continue to next search instead of stopping
                        continue
                
                # Convert set to list and filter out strings (keep only repo objects)
                repo_list = [r for r in all_repos if hasattr(r, 'full_name')]
                
                self.logger.info(f"[TOTAL] Found {len(repo_list)} unique repositories in time window {start_window.strftime('%Y-%m-%d')} to {end_window.strftime('%Y-%m-%d')}")
                
                # Process repositories found in this time window
                if repo_list:
                    self.batch_process_repositories(repo_list)
                
                # Move to next time window
                current_date = start_window
                
                # Update current date in progress
                with self.progress_lock:
                    self.progress['current_date'] = current_date.strftime('%Y-%m-%d')
                
                # Check memory usage
                if time.time() - self.last_gc_time > self.gc_interval:
                    gc.collect()
                    self.last_gc_time = time.time()
                
                # Save statistics and progress after each time window
                self.stats.save(self.output_dir)
                self.save_progress()
                
        except Exception as e:
            self.logger.error(f"[ERROR] Search error: {str(e)}")
        
        finally:
            # Save final statistics
            self.stats.save(self.output_dir)
            self.save_progress()
    
    def run(self):
        """Run scanner"""
        start_time = datetime.now()
        self.logger.info("[START] Starting Ultra Fast Traefik Scanner")
        self.logger.info("=" * 50)
        
        try:
            self.search_repositories_ultra_fast()
        except KeyboardInterrupt:
            self.logger.info("[STOP] Scan interrupted by user")
            self.save_progress()
        except Exception as e:
            self.logger.error(f"[ERROR] Unexpected error: {str(e)}")
            self.save_progress()
        finally:
            self.result_writer.force_save()
            
            summary = self.stats.get_summary()
            duration = datetime.now() - start_time
            
            self.logger.info("=" * 50)
            self.logger.info("[STATS] Scan completed. Final statistics:")
            self.logger.info(f"   Total repositories processed: {summary['total_repos_processed']}")
            self.logger.info(f"   Total matches: {summary['total_matches']}")
            self.logger.info(f"   Duration: {duration.total_seconds():.2f} seconds")
            
            if duration.total_seconds() > 0:
                speed = summary['total_repos_processed'] / duration.total_seconds() * 60
                self.logger.info(f"   Average speed: {speed:.1f} repos/minute")


class TraefikResultWriter:
    """Traefik 结果写入器"""
    
    def __init__(self, csv_file, excel_file):
        self.csv_file = csv_file
        self.excel_file = excel_file
        self.written_set = set()
        self.result_index = 1
        self.lock = threading.Lock()
        
        # Initialize CSV file
        with open(self.csv_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow([
                'Index', 'Repository', 'URL', 'Stars', 'Year',
                'Vulnerability Type', 'Risk Level', 'Has TrustedIPs', 'File Path'
            ])
    
    def write(self, repo_name, repo_url, stars, year, matches_by_filter):
        """Write results"""
        with self.lock:
            repo_key = (repo_name, repo_url, stars, year)
            if repo_key in self.written_set:
                return False
            
            self.written_set.add(repo_key)
            
            # Write to CSV
            with open(self.csv_file, 'a', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                
                for filter_name, matches in matches_by_filter.items():
                    for match in matches:
                        writer.writerow([
                            self.result_index,
                            repo_name,
                            repo_url,
                            stars,
                            year,
                            filter_name,
                            match['risk_level'],
                            'Yes' if match['has_trusted_ips'] else 'No',
                            match['file_path']
                        ])
                        self.result_index += 1
            
            return True
    
    def force_save(self):
        """Force save (for Excel, if needed)"""
        pass


class TraefikSearchStats:
    """Traefik 搜索统计"""
    
    def __init__(self):
        self.total_repos_processed = 0
        self.total_matches = 0
        self.repos_by_stars = defaultdict(int)
        self.matches_by_type = defaultdict(int)
        self.start_time = datetime.now()
        self._lock = threading.Lock()
    
    def update(self, repo_stars=None, matches=0, match_type=None):
        with self._lock:
            self.total_repos_processed += 1
            self.total_matches += matches
            if repo_stars:
                self.repos_by_stars[repo_stars] += 1
            if match_type:
                self.matches_by_type[match_type] += 1
    
    def get_summary(self):
        return {
            'total_repos_processed': self.total_repos_processed,
            'total_matches': self.total_matches,
            'repos_by_stars': dict(self.repos_by_stars),
            'matches_by_type': dict(self.matches_by_type),
            'duration_seconds': (datetime.now() - self.start_time).total_seconds(),
            'last_updated': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    def save(self, output_dir):
        stats_file = output_dir / 'stats.json'
        with open(stats_file, 'w', encoding='utf-8') as f:
            json.dump(self.get_summary(), f, indent=4)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Ultra Fast Traefik Configuration Scanner',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        '--config', '-c',
        default='config.json',
        help='Configuration file path (default: config.json)'
    )
    
    parser.add_argument(
        '--workers', '-w',
        type=int,
        default=16,
        help='Number of worker threads (default: 16)'
    )
    
    args = parser.parse_args()
    
    # Check if .env file exists
    if not os.path.exists('.env'):
        print("Warning: .env file not found!")
        print("Please create a .env file with your GITHUB_TOKEN")
        print("Example: GITHUB_TOKEN=your_github_token_here")
        print("For multiple tokens: GITHUB_TOKEN=token1,token2,token3")
        exit(1)
    
    try:
        # Load config
        config = {}
        if os.path.exists(args.config):
            with open(args.config, 'r', encoding='utf-8') as f:
                config = json.load(f)
        
        # Override workers
        if 'concurrency' not in config:
            config['concurrency'] = {}
        config['concurrency']['max_workers'] = args.workers
        
        # Create scanner
        scanner = UltraFastTraefikScanner(config_override=config)
        
        print("\n" + "="*60)
        print("TRAEFIK SCANNER CONFIGURATION")
        print("="*60)
        print(f"Workers:      {args.workers}")
        print(f"Output Dir:   {scanner.output_dir}")
        print(f"CSV File:     {scanner.csv_file}")
        print("="*60)
        
        # Start scanning
        print(f"\n[START] Starting Traefik configuration scan...")
        scanner.run()
        
    except KeyboardInterrupt:
        print("\n[STOP] Scan interrupted by user")
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {e}")
        import traceback
        traceback.print_exc()

