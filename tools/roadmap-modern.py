#!/usr/bin/env python3
"""
Modern Roadmap Viewer - Kitty-style interface with better visuals
"""
import os
import sys
from pathlib import Path
import json
from datetime import datetime
from typing import Optional, List, Dict
import argparse

# ANSI color codes for modern terminal styling
class Colors:
    # Reset
    RESET = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    ITALIC = '\033[3m'
    UNDERLINE = '\033[4m'
    
    # Foreground colors
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    
    # Bright colors
    BRIGHT_BLACK = '\033[90m'
    BRIGHT_RED = '\033[91m'
    BRIGHT_GREEN = '\033[92m'
    BRIGHT_YELLOW = '\033[93m'
    BRIGHT_BLUE = '\033[94m'
    BRIGHT_MAGENTA = '\033[95m'
    BRIGHT_CYAN = '\033[96m'
    BRIGHT_WHITE = '\033[97m'
    
    # Background colors
    BG_BLACK = '\033[40m'
    BG_RED = '\033[41m'
    BG_GREEN = '\033[42m'
    BG_YELLOW = '\033[43m'
    BG_BLUE = '\033[44m'
    BG_MAGENTA = '\033[45m'
    BG_CYAN = '\033[46m'
    BG_WHITE = '\033[47m'
    
    # 256 color support
    @staticmethod
    def fg256(n):
        return f'\033[38;5;{n}m'
    
    @staticmethod
    def bg256(n):
        return f'\033[48;5;{n}m'

# Unicode box drawing characters
class Box:
    # Single line
    H = '─'
    V = '│'
    TL = '┌'
    TR = '┐'
    BL = '└'
    BR = '┘'
    T = '┬'
    B = '┴'
    L = '├'
    R = '┤'
    CROSS = '┼'
    
    # Double line
    DH = '═'
    DV = '║'
    DTL = '╔'
    DTR = '╗'
    DBL = '╚'
    DBR = '╝'
    
    # Rounded
    RTL = '╭'
    RTR = '╮'
    RBL = '╰'
    RBR = '╯'

# Icons
class Icons:
    TODO = '○'
    IN_PROGRESS = '◐'
    DONE = '●'
    BLOCKED = '⊗'
    
    CRITICAL = '🔴'
    HIGH = '🟠'
    MEDIUM = '🟡'
    LOW = '🟢'
    
    MILESTONE = '🎯'
    TASK = '📋'
    LINK = '🔗'
    DOC = '📄'
    DETAILS = '📝'
    
    ARROW_RIGHT = '→'
    ARROW_DOWN = '↓'
    CHECK = '✓'
    CROSS = '✗'
    STAR = '★'
    
    # Decorative
    CHEVRON = '❯'
    BULLET = '•'
    DIAMOND = '◆'

class ModernRoadmapViewer:
    def __init__(self, workspace_root: str):
        self.workspace_root = Path(workspace_root)
        self.roadmap_dir = self.workspace_root / 'roadmap'
        self.tasks_file = self.roadmap_dir / 'tasks.json'
        self.tasks = self.load_tasks()
        
    def load_tasks(self) -> Dict:
        """Load tasks from JSON file"""
        if self.tasks_file.exists():
            with open(self.tasks_file, 'r') as f:
                return json.load(f)
        return {}
    
    def clear_screen(self):
        """Clear terminal screen"""
        os.system('clear' if os.name == 'posix' else 'cls')
    
    def print_header(self):
        """Print stylish header"""
        width = os.get_terminal_size().columns
        
        # Top border
        print(f"{Colors.BRIGHT_CYAN}{Box.RTL}{Box.H * (width-2)}{Box.RTR}{Colors.RESET}")
        
        # Title
        title = "AppFlowy Studios Roadmap"
        subtitle = "Task Management System"
        padding = (width - len(title) - 2) // 2
        print(f"{Colors.BRIGHT_CYAN}{Box.V}{Colors.RESET}" + 
              f"{' ' * padding}{Colors.BOLD}{Colors.BRIGHT_WHITE}{title}{Colors.RESET}" +
              f"{' ' * (width - len(title) - padding - 2)}" +
              f"{Colors.BRIGHT_CYAN}{Box.V}{Colors.RESET}")
        
        padding_sub = (width - len(subtitle) - 2) // 2
        print(f"{Colors.BRIGHT_CYAN}{Box.V}{Colors.RESET}" + 
              f"{' ' * padding_sub}{Colors.DIM}{Colors.BRIGHT_BLUE}{subtitle}{Colors.RESET}" +
              f"{' ' * (width - len(subtitle) - padding_sub - 2)}" +
              f"{Colors.BRIGHT_CYAN}{Box.V}{Colors.RESET}")
        
        # Bottom border
        print(f"{Colors.BRIGHT_CYAN}{Box.RBL}{Box.H * (width-2)}{Box.RBR}{Colors.RESET}")
        print()
    
    def print_stats(self):
        """Print task statistics"""
        total = len(self.tasks)
        todo = sum(1 for t in self.tasks.values() if t.get('status') == 'todo')
        in_progress = sum(1 for t in self.tasks.values() if t.get('status') == 'in_progress')
        done = sum(1 for t in self.tasks.values() if t.get('status') == 'done')
        blocked = sum(1 for t in self.tasks.values() if t.get('status') == 'blocked')
        
        print(f"{Colors.BOLD}📊 Statistics{Colors.RESET}")
        print(f"{Colors.BRIGHT_BLACK}{Box.H * 40}{Colors.RESET}")
        
        # Progress bar
        if total > 0:
            progress = (done / total) * 100
            bar_width = 30
            filled = int((done / total) * bar_width)
            
            bar = f"{Colors.BRIGHT_GREEN}{'█' * filled}{Colors.BRIGHT_BLACK}{'░' * (bar_width - filled)}{Colors.RESET}"
            print(f"Progress: {bar} {progress:.1f}%")
            print()
        
        # Stats grid
        stats = [
            (f"{Icons.TODO} Todo", todo, Colors.BRIGHT_BLUE),
            (f"{Icons.IN_PROGRESS} In Progress", in_progress, Colors.BRIGHT_YELLOW),
            (f"{Icons.DONE} Completed", done, Colors.BRIGHT_GREEN),
            (f"{Icons.BLOCKED} Blocked", blocked, Colors.BRIGHT_RED)
        ]
        
        for label, count, color in stats:
            print(f"  {color}{label:{20}} {count:3}{Colors.RESET}")
        print()
    
    def get_status_icon(self, status: str) -> str:
        """Get icon for status"""
        return {
            'todo': Icons.TODO,
            'in_progress': Icons.IN_PROGRESS,
            'done': Icons.DONE,
            'blocked': Icons.BLOCKED
        }.get(status, Icons.TODO)
    
    def get_status_color(self, status: str) -> str:
        """Get color for status"""
        return {
            'todo': Colors.BRIGHT_BLUE,
            'in_progress': Colors.BRIGHT_YELLOW,
            'done': Colors.BRIGHT_GREEN,
            'blocked': Colors.BRIGHT_RED
        }.get(status, Colors.WHITE)
    
    def get_priority_icon(self, priority: str) -> str:
        """Get icon for priority"""
        return {
            'critical': Icons.CRITICAL,
            'high': Icons.HIGH,
            'medium': Icons.MEDIUM,
            'low': Icons.LOW
        }.get(priority, Icons.LOW)
    
    def format_text(self, text: str, width: int) -> List[str]:
        """Wrap text to specified width"""
        words = text.split()
        lines = []
        current_line = []
        current_length = 0
        
        for word in words:
            if current_length + len(word) + 1 <= width:
                current_line.append(word)
                current_length += len(word) + 1
            else:
                if current_line:
                    lines.append(' '.join(current_line))
                current_line = [word]
                current_length = len(word)
        
        if current_line:
            lines.append(' '.join(current_line))
        
        return lines if lines else ['']
    
    def print_task_card(self, task_id: str, task: Dict, detailed: bool = False):
        """Print a task as a card"""
        width = min(100, os.get_terminal_size().columns - 4)
        
        status = task.get('status', 'todo')
        priority = task.get('priority', 'low')
        status_icon = self.get_status_icon(status)
        status_color = self.get_status_color(status)
        priority_icon = self.get_priority_icon(priority)
        
        # Card border
        print(f"{Colors.BRIGHT_BLACK}{Box.RTL}{Box.H * (width-2)}{Box.RTR}{Colors.RESET}")
        
        # Header line
        header = f"{status_icon} {task_id} - {task.get('title', 'Untitled')}"
        milestone = task.get('milestone', '')
        if milestone:
            milestone_text = f"{Icons.MILESTONE} {milestone}"
            header_width = width - len(milestone_text) - 6
            print(f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET} " +
                  f"{status_color}{header[:header_width]}{Colors.RESET}" +
                  f"{' ' * (header_width - len(header[:header_width]))} " +
                  f"{Colors.BRIGHT_MAGENTA}{milestone_text}{Colors.RESET} " +
                  f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET}")
        else:
            print(f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET} " +
                  f"{status_color}{header:{width-4}}{Colors.RESET} " +
                  f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET}")
        
        # Priority and status line
        status_line = f"{priority_icon} {priority.title()} Priority"
        print(f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET} " +
              f"{Colors.DIM}{status_line:{width-4}}{Colors.RESET} " +
              f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET}")
        
        if detailed:
            # Separator
            print(f"{Colors.BRIGHT_BLACK}{Box.L}{Box.H * (width-2)}{Box.R}{Colors.RESET}")
            
            # Description
            if task.get('description'):
                desc_lines = self.format_text(task['description'], width - 6)
                for line in desc_lines[:3]:
                    print(f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET}  " +
                          f"{Colors.WHITE}{line:{width-5}}{Colors.RESET} " +
                          f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET}")
            
            # Links
            if task.get('links'):
                print(f"{Colors.BRIGHT_BLACK}{Box.L}{Box.H * (width-2)}{Box.R}{Colors.RESET}")
                print(f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET}  " +
                      f"{Colors.BRIGHT_CYAN}{Icons.LINK} Related Documents:{Colors.RESET}" +
                      f"{' ' * (width - 23)} " +
                      f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET}")
                
                for link in task['links'][:3]:
                    link_text = f"  {Icons.DOC} {link['name']}"
                    print(f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET}  " +
                          f"{Colors.BRIGHT_BLUE}{link_text:{width-5}}{Colors.RESET} " +
                          f"{Colors.BRIGHT_BLACK}{Box.V}{Colors.RESET}")
        
        # Bottom border
        print(f"{Colors.BRIGHT_BLACK}{Box.RBL}{Box.H * (width-2)}{Box.RBR}{Colors.RESET}")
    
    def list_tasks_by_milestone(self, interactive=True):
        """List all tasks grouped by milestone"""
        # Group tasks by milestone
        milestones = {}
        all_tasks_ordered = []  # Keep track of display order
        
        for task_id, task in self.tasks.items():
            milestone = task.get('milestone', 'Unassigned')
            if milestone not in milestones:
                milestones[milestone] = []
            milestones[milestone].append((task_id, task))
        
        # Sort milestones
        sorted_milestones = sorted(milestones.keys())
        
        task_number = 1
        task_map = {}  # Map number to task_id for selection
        
        for milestone in sorted_milestones:
            # Milestone header
            print(f"\n{Colors.BOLD}{Colors.BRIGHT_MAGENTA}{Icons.MILESTONE} Milestone {milestone}{Colors.RESET}")
            print(f"{Colors.BRIGHT_BLACK}{'═' * 60}{Colors.RESET}\n")
            
            # Sort tasks by priority
            priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
            tasks = sorted(milestones[milestone], 
                          key=lambda t: (priority_order.get(t[1].get('priority', 'low'), 4), t[0]))
            
            for task_id, task in tasks:
                if interactive:
                    # Add selection number
                    print(f"{Colors.BRIGHT_CYAN}[{task_number}]{Colors.RESET}")
                    task_map[str(task_number)] = task_id
                    task_number += 1
                
                self.print_task_card(task_id, task, detailed=False)
                print()  # Space between cards
        
        if interactive:
            return task_map
        return None
    
    def load_prd_content(self, url: str, task_id: str) -> str:
        """Load content from PRD file for a specific task"""
        # Convert relative URL to absolute path
        if url.startswith('../'):
            prd_path = self.workspace_root.parent / url[3:]
        else:
            prd_path = self.workspace_root.parent / url
            
        if not prd_path.exists():
            return f"PRD file not found: {prd_path}"
        
        try:
            with open(prd_path, 'r') as f:
                content = f.read()
            
            # Search for task-specific content using the task ID tag
            import re
            
            # Look for sections tagged with this task ID
            task_pattern = rf'\[task-id:\s*{task_id}\]'
            
            # Also look for a section header with the task ID
            header_pattern = rf'#{1,3}\s+.*?{task_id}.*?\n'
            
            # Find all matches
            lines = content.split('\n')
            task_content = []
            capturing = False
            section_level = 0
            
            for i, line in enumerate(lines):
                # Check if this line contains our task ID
                if re.search(task_pattern, line, re.IGNORECASE) or re.search(header_pattern, line, re.IGNORECASE):
                    capturing = True
                    # Determine the section level if it's a header
                    if line.startswith('#'):
                        section_level = len(line.split(' ')[0])
                    task_content.append(line)
                elif capturing:
                    # Stop capturing if we hit another section of equal or higher level
                    if line.startswith('#'):
                        current_level = len(line.split(' ')[0])
                        if current_level <= section_level and section_level > 0:
                            # Check if this new section is for a different task
                            if not re.search(rf'{task_id}', line, re.IGNORECASE):
                                break
                    task_content.append(line)
            
            return '\n'.join(task_content) if task_content else ""
        except Exception as e:
            return f"Error reading PRD: {str(e)}"
    
    def show_task_detail(self, task_id: str, wait_for_input=True):
        """Show detailed view of a specific task"""
        if task_id not in self.tasks:
            print(f"{Colors.BRIGHT_RED}❌ Task {task_id} not found{Colors.RESET}")
            return
        
        task = self.tasks[task_id]
        self.clear_screen()
        self.print_header()
        
        print(f"\n{Colors.BOLD}{Colors.BRIGHT_CYAN}Task Details{Colors.RESET}\n")
        self.print_task_card(task_id, task, detailed=True)
        
        # Load implementation details from linked PRDs
        prd_contents = []
        if task.get('links'):
            for link in task['links']:
                if 'Technical PRD' in link['name'] or 'technical' in link['name'].lower():
                    # Prioritize technical PRDs for implementation details
                    content = self.load_prd_content(link['url'], task_id)
                    if content and content != f"PRD file not found: {link['url']}":
                        prd_contents.insert(0, (link['name'], content))
                else:
                    content = self.load_prd_content(link['url'], task_id)
                    if content and content != f"PRD file not found: {link['url']}":
                        prd_contents.append((link['name'], content))
        
        # Show implementation details from PRDs
        if prd_contents:
            for doc_name, content in prd_contents:
                if content:
                    print(f"\n{Colors.BOLD}{Colors.BRIGHT_YELLOW}{Icons.DETAILS} Implementation Details from {doc_name}{Colors.RESET}")
                    print(f"{Colors.BRIGHT_BLACK}{'═' * 80}{Colors.RESET}\n")
                    
                    self.format_and_print_content(content)
                    print(f"\n{Colors.BRIGHT_BLACK}{'═' * 80}{Colors.RESET}")
        
        # Also show inline details if they exist
        if task.get('details') and len(task['details']) > 100:  # Only if substantial
            print(f"\n{Colors.BOLD}{Colors.BRIGHT_YELLOW}{Icons.DETAILS} Additional Notes{Colors.RESET}")
            print(f"{Colors.BRIGHT_BLACK}{'═' * 80}{Colors.RESET}\n")
            self.format_and_print_content(task['details'])
            print(f"\n{Colors.BRIGHT_BLACK}{'═' * 80}{Colors.RESET}")
        
        # Show subtasks if any
        if task.get('subtasks') and len(task['subtasks']) > 0:
            print(f"\n{Colors.BOLD}{Colors.BRIGHT_MAGENTA}📝 Subtasks{Colors.RESET}")
            print(f"{Colors.BRIGHT_BLACK}{'─' * 40}{Colors.RESET}\n")
            for subtask_id in task['subtasks']:
                if subtask_id in self.tasks:
                    subtask = self.tasks[subtask_id]
                    status_icon = self.get_status_icon(subtask.get('status', 'todo'))
                    print(f"  {status_icon} {subtask_id}: {subtask.get('title', 'Untitled')}")
        
        if wait_for_input:
            input(f"\n{Colors.DIM}Press Enter to continue...{Colors.RESET}")
    
    def format_and_print_content(self, content: str):
        """Format and print content with syntax highlighting"""
        detail_lines = content.split('\n')
        in_code_block = False
        
        for line in detail_lines:  # No limit - show everything
            stripped = line.strip()
            
            # Handle code blocks
            if '```' in line:
                in_code_block = not in_code_block
                print(f"{Colors.BRIGHT_BLACK}{'─' * 60}{Colors.RESET}")
                if '```bash' in line or '```shell' in line:
                    print(f"{Colors.BRIGHT_GREEN}📦 Shell Command:{Colors.RESET}")
                elif '```hcl' in line or '```terraform' in line:
                    print(f"{Colors.BRIGHT_MAGENTA}🔧 Terraform Configuration:{Colors.RESET}")
                elif '```yaml' in line or '```yml' in line:
                    print(f"{Colors.BRIGHT_CYAN}📋 YAML Configuration:{Colors.RESET}")
                elif '```' in line and not in_code_block:
                    print(f"{Colors.BRIGHT_BLACK}{'─' * 60}{Colors.RESET}")
                continue
            
            if in_code_block:
                # Code content - use a different color
                print(f"{Colors.BRIGHT_YELLOW}{line}{Colors.RESET}")
            elif stripped.startswith('##'):
                # Section header
                print(f"\n{Colors.BOLD}{Colors.BRIGHT_CYAN}{line}{Colors.RESET}")
                print(f"{Colors.BRIGHT_BLACK}{'─' * 40}{Colors.RESET}")
            elif stripped.startswith('#'):
                # Header
                print(f"\n{Colors.BOLD}{Colors.BRIGHT_MAGENTA}{line}{Colors.RESET}")
            elif stripped.startswith('*') and not stripped.startswith('**'):
                # Bullet point
                formatted = line.replace('*', f'{Colors.BRIGHT_GREEN}•{Colors.RESET}', 1)
                print(f"{formatted}")
            elif stripped.startswith('**') and stripped.endswith('**'):
                # Bold text
                content = stripped.strip('*')
                print(f"{Colors.BOLD}{Colors.BRIGHT_WHITE}{content}{Colors.RESET}")
            elif stripped.startswith('1.') or stripped.startswith('2.') or stripped.startswith('3.'):
                # Numbered list
                print(f"{Colors.BRIGHT_BLUE}{line}{Colors.RESET}")
            elif '[' in line and '](' in line:
                # Link
                print(f"{Colors.BRIGHT_BLUE}{line}{Colors.RESET}")
            elif stripped.startswith('|'):
                # Table
                print(f"{Colors.CYAN}{line}{Colors.RESET}")
            elif stripped.startswith('─') or stripped.startswith('═'):
                # Separator
                print(f"{Colors.BRIGHT_BLACK}{line}{Colors.RESET}")
            else:
                # Regular text
                print(f"{Colors.WHITE}{line}{Colors.RESET}")
    
    def interactive_menu(self):
        """Show interactive menu"""
        while True:
            self.clear_screen()
            self.print_header()
            self.print_stats()
            
            print(f"{Colors.BOLD}{Colors.BRIGHT_CYAN}📋 Menu{Colors.RESET}")
            print(f"{Colors.BRIGHT_BLACK}{'─' * 40}{Colors.RESET}\n")
            
            options = [
                ("1", "View all tasks by milestone", Colors.BRIGHT_BLUE),
                ("2", "View specific task details", Colors.BRIGHT_GREEN),
                ("3", "Filter by status", Colors.BRIGHT_YELLOW),
                ("4", "Filter by priority", Colors.BRIGHT_MAGENTA),
                ("5", "Search tasks", Colors.BRIGHT_CYAN),
                ("q", "Quit", Colors.BRIGHT_RED)
            ]
            
            for key, desc, color in options:
                print(f"  {color}[{key}]{Colors.RESET} {desc}")
            
            print(f"\n{Colors.BRIGHT_BLACK}{'─' * 40}{Colors.RESET}")
            choice = input(f"{Colors.BRIGHT_GREEN}{Icons.CHEVRON}{Colors.RESET} Select option: ").strip().lower()
            
            if choice == '1':
                self.clear_screen()
                self.print_header()
                task_map = self.list_tasks_by_milestone(interactive=True)
                
                # Ask if user wants to view a specific task
                print(f"\n{Colors.BRIGHT_BLACK}{'─' * 60}{Colors.RESET}")
                print(f"{Colors.BRIGHT_CYAN}Enter task number to view details, or press Enter to return to menu{Colors.RESET}")
                selection = input(f"{Colors.BRIGHT_GREEN}{Icons.CHEVRON}{Colors.RESET} Select task: ").strip()
                
                if selection and selection in task_map:
                    self.show_task_detail(task_map[selection])
                elif selection:
                    print(f"{Colors.BRIGHT_RED}Invalid selection{Colors.RESET}")
                    input(f"{Colors.DIM}Press Enter to continue...{Colors.RESET}")
            
            elif choice == '2':
                task_id = input(f"{Colors.BRIGHT_GREEN}{Icons.CHEVRON}{Colors.RESET} Enter task ID: ").strip().upper()
                self.show_task_detail(task_id)
                input(f"\n{Colors.DIM}Press Enter to continue...{Colors.RESET}")
            
            elif choice == '3':
                self.filter_by_status()
            
            elif choice == '4':
                self.filter_by_priority()
            
            elif choice == '5':
                self.search_tasks()
            
            elif choice == 'q':
                print(f"\n{Colors.BRIGHT_GREEN}✨ Goodbye!{Colors.RESET}")
                break
    
    def filter_by_status(self):
        """Filter tasks by status"""
        self.clear_screen()
        self.print_header()
        
        print(f"{Colors.BOLD}{Colors.BRIGHT_YELLOW}Filter by Status{Colors.RESET}\n")
        
        statuses = ['todo', 'in_progress', 'done', 'blocked']
        for i, status in enumerate(statuses, 1):
            icon = self.get_status_icon(status)
            color = self.get_status_color(status)
            print(f"  {color}[{i}] {icon} {status.replace('_', ' ').title()}{Colors.RESET}")
        
        choice = input(f"\n{Colors.BRIGHT_GREEN}{Icons.CHEVRON}{Colors.RESET} Select status: ").strip()
        
        if choice.isdigit() and 1 <= int(choice) <= len(statuses):
            selected_status = statuses[int(choice) - 1]
            filtered_tasks = {tid: task for tid, task in self.tasks.items() 
                            if task.get('status') == selected_status}
            
            print(f"\n{Colors.BOLD}Tasks with status: {selected_status}{Colors.RESET}\n")
            
            for task_id, task in filtered_tasks.items():
                self.print_task_card(task_id, task, detailed=False)
                print()
            
            if not filtered_tasks:
                print(f"{Colors.DIM}No tasks found with this status{Colors.RESET}")
            
            input(f"\n{Colors.DIM}Press Enter to continue...{Colors.RESET}")
    
    def filter_by_priority(self):
        """Filter tasks by priority"""
        self.clear_screen()
        self.print_header()
        
        print(f"{Colors.BOLD}{Colors.BRIGHT_MAGENTA}Filter by Priority{Colors.RESET}\n")
        
        priorities = ['critical', 'high', 'medium', 'low']
        for i, priority in enumerate(priorities, 1):
            icon = self.get_priority_icon(priority)
            print(f"  [{i}] {icon} {priority.title()}")
        
        choice = input(f"\n{Colors.BRIGHT_GREEN}{Icons.CHEVRON}{Colors.RESET} Select priority: ").strip()
        
        if choice.isdigit() and 1 <= int(choice) <= len(priorities):
            selected_priority = priorities[int(choice) - 1]
            filtered_tasks = {tid: task for tid, task in self.tasks.items() 
                            if task.get('priority') == selected_priority}
            
            print(f"\n{Colors.BOLD}Tasks with priority: {selected_priority}{Colors.RESET}\n")
            
            for task_id, task in filtered_tasks.items():
                self.print_task_card(task_id, task, detailed=False)
                print()
            
            if not filtered_tasks:
                print(f"{Colors.DIM}No tasks found with this priority{Colors.RESET}")
            
            input(f"\n{Colors.DIM}Press Enter to continue...{Colors.RESET}")
    
    def search_tasks(self):
        """Search tasks by keyword"""
        self.clear_screen()
        self.print_header()
        
        print(f"{Colors.BOLD}{Colors.BRIGHT_CYAN}Search Tasks{Colors.RESET}\n")
        
        keyword = input(f"{Colors.BRIGHT_GREEN}{Icons.CHEVRON}{Colors.RESET} Enter search term: ").strip().lower()
        
        if not keyword:
            return
        
        found_tasks = {}
        for task_id, task in self.tasks.items():
            # Search in title, description, and details
            searchable = [
                task.get('title', ''),
                task.get('description', ''),
                task.get('details', '')
            ]
            
            if any(keyword in field.lower() for field in searchable):
                found_tasks[task_id] = task
        
        print(f"\n{Colors.BOLD}Search results for '{keyword}':{Colors.RESET}\n")
        
        for task_id, task in found_tasks.items():
            self.print_task_card(task_id, task, detailed=False)
            print()
        
        if not found_tasks:
            print(f"{Colors.DIM}No tasks found matching '{keyword}'{Colors.RESET}")
        
        input(f"\n{Colors.DIM}Press Enter to continue...{Colors.RESET}")

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Modern Roadmap Viewer')
    parser.add_argument('--list', action='store_true', help='List all tasks')
    parser.add_argument('--task', type=str, help='Show specific task details')
    parser.add_argument('--status', type=str, help='Filter by status')
    parser.add_argument('--priority', type=str, help='Filter by priority')
    
    args = parser.parse_args()
    
    workspace_root = os.environ.get('WORKSPACE_ROOT', '/home/jb/workspace/projects/tools/appflowy-studios/docs')
    viewer = ModernRoadmapViewer(workspace_root)
    
    if args.list:
        viewer.clear_screen()
        viewer.print_header()
        task_map = viewer.list_tasks_by_milestone(interactive=True)
        
        # Ask if user wants to view a specific task
        print(f"\n{Colors.BRIGHT_BLACK}{'─' * 60}{Colors.RESET}")
        print(f"{Colors.BRIGHT_CYAN}Enter task number to view details, or press Enter to exit{Colors.RESET}")
        selection = input(f"{Colors.BRIGHT_GREEN}{Icons.CHEVRON}{Colors.RESET} Select task: ").strip()
        
        if selection and selection in task_map:
            viewer.show_task_detail(task_map[selection])
        elif selection:
            print(f"{Colors.BRIGHT_RED}Invalid selection{Colors.RESET}")
    elif args.task:
        viewer.show_task_detail(args.task.upper())
    elif args.status or args.priority:
        # Command line filtering
        viewer.clear_screen()
        viewer.print_header()
        
        filtered = viewer.tasks
        if args.status:
            filtered = {tid: task for tid, task in filtered.items() 
                       if task.get('status') == args.status}
        if args.priority:
            filtered = {tid: task for tid, task in filtered.items() 
                       if task.get('priority') == args.priority}
        
        for task_id, task in filtered.items():
            viewer.print_task_card(task_id, task, detailed=False)
            print()
    else:
        # Interactive mode
        viewer.interactive_menu()

if __name__ == "__main__":
    main()