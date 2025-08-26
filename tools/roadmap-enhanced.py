#!/usr/bin/env python3
"""
Enhanced Roadmap TUI with task details and links display
"""
import os
import sys
from pathlib import Path

# Add the parent tools directory to path to import the roadmap module
tools_dir = Path(__file__).parent.parent.parent
sys.path.insert(0, str(tools_dir / 'roadmaptool'))

import curses
from datetime import datetime
import json
from typing import Optional, List, Dict

# Import the base RoadmapTool and Task
from roadmap import Task

class EnhancedTask(Task):
    """Extended Task class with additional fields"""
    def __init__(self, task_id: str, title: str, status: str = 'todo', 
                 priority: str = 'medium', project: str = 'workspace',
                 description: str = '', milestone: str = '', 
                 created: Optional[str] = None, updated: Optional[str] = None,
                 details: str = '', links: Optional[List[Dict]] = None, 
                 subtasks: Optional[List[str]] = None):
        super().__init__(task_id, title, status, priority, project, 
                        description, milestone, created, updated)
        self.details = details
        self.links = links or []
        self.subtasks = subtasks or []
    
    def to_dict(self):
        data = super().to_dict()
        data['details'] = self.details
        data['links'] = self.links
        data['subtasks'] = self.subtasks
        return data
    
    @classmethod
    def from_dict(cls, data):
        # Extract known fields
        task_data = data.copy()
        task_id = task_data.pop('id')
        
        # Extract extended fields with defaults
        details = task_data.pop('details', '')
        links = task_data.pop('links', [])
        subtasks = task_data.pop('subtasks', [])
        
        # Create task with all fields
        return cls(task_id=task_id, details=details, links=links, 
                  subtasks=subtasks, **task_data)

class EnhancedRoadmapTool:
    """Extended RoadmapTool that uses EnhancedTask"""
    def __init__(self, workspace_root: str):
        self.workspace_root = Path(workspace_root)
        self.roadmap_dir = self.workspace_root / 'roadmap'
        self.roadmap_dir.mkdir(exist_ok=True)
        self.tasks_file = self.roadmap_dir / 'tasks.json'
        self.tasks = self.load_tasks()
    
    def load_tasks(self) -> Dict[str, EnhancedTask]:
        """Load tasks from JSON file"""
        if self.tasks_file.exists():
            with open(self.tasks_file, 'r') as f:
                data = json.load(f)
                return {tid: EnhancedTask.from_dict(tdata) for tid, tdata in data.items()}
        return {}
    
    def save_tasks(self):
        """Save tasks to JSON file"""
        data = {tid: task.to_dict() for tid, task in self.tasks.items()}
        with open(self.tasks_file, 'w') as f:
            json.dump(data, f, indent=2)

class EnhancedRoadmapTUI:
    def __init__(self, workspace_root: str):
        self.tool = EnhancedRoadmapTool(workspace_root)
        self.selected_index = 0
        self.scroll_offset = 0
        self.filter_status = None
        self.filter_priority = None
        self.filter_milestone = None
        self.view_mode = 'split'  # 'list' or 'split'
        
    def get_filtered_tasks(self) -> List[EnhancedTask]:
        """Get filtered and sorted tasks"""
        tasks = list(self.tool.tasks.values())
        
        # Apply filters
        if self.filter_status:
            tasks = [t for t in tasks if t.status == self.filter_status]
        if self.filter_priority:
            tasks = [t for t in tasks if t.priority == self.filter_priority]
        if self.filter_milestone:
            tasks = [t for t in tasks if t.milestone == self.filter_milestone]
        
        # Sort by priority then milestone
        priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
        tasks.sort(key=lambda t: (
            priority_order.get(t.priority, 4),
            t.milestone,
            t.id
        ))
        
        return tasks
    
    def draw_task_list(self, stdscr, tasks: List[EnhancedTask], height: int, width: int, start_y: int, start_x: int, list_width: int):
        """Draw the task list on the left side"""
        # Ensure we don't exceed boundaries
        if list_width < 30:  # Minimum width for list
            return
            
        # Adjust column widths based on available space
        id_width = min(6, list_width // 5)
        status_width = min(8, list_width // 4)
        pri_width = 2
        m_width = 2
        # Give remaining space to title
        title_width = max(10, list_width - id_width - status_width - pri_width - m_width - 5)
        
        # Header
        header = f"{'ID':<{id_width}} {'Status':<{status_width}} {'P':<{pri_width}} {'M':<{m_width}} {'Title':<{title_width}}"
        try:
            stdscr.addstr(start_y, start_x, header[:min(list_width-1, len(header))], curses.A_BOLD | curses.color_pair(4))
            stdscr.addstr(start_y + 1, start_x, "─" * min(list_width - 1, width - start_x - 1))
        except curses.error:
            pass  # Ignore if we can't draw
        
        # Tasks
        visible_tasks = tasks[self.scroll_offset:self.scroll_offset + height - 3]
        for i, task in enumerate(visible_tasks):
            y = start_y + 2 + i
            
            # Determine colors
            if i + self.scroll_offset == self.selected_index:
                attr = curses.A_REVERSE
            else:
                attr = 0
            
            # Status color
            status_colors = {
                'todo': curses.color_pair(1),
                'in_progress': curses.color_pair(3),
                'done': curses.color_pair(2),
                'blocked': curses.color_pair(1)
            }
            
            # Priority indicator (shorter)
            pri_map = {'critical': '!!!', 'high': '!!', 'medium': '!', 'low': '-'}
            pri = pri_map.get(task.priority, '-')
            
            # Truncate title if needed
            truncated_title = task.title if len(task.title) <= title_width else task.title[:title_width-3] + '...'
            
            # Format line with dynamic widths
            line = f"{task.id:<{id_width}} {task.status:<{status_width}} {pri:<{pri_width}} {task.milestone or '-':<{m_width}} {truncated_title:<{title_width}}"
            
            if y < start_y + height - 1 and y < curses.LINES - 1:
                # Draw with appropriate color
                try:
                    if i + self.scroll_offset == self.selected_index:
                        safe_line = line[:min(list_width-1, curses.COLS - start_x - 1)]
                        stdscr.addstr(y, start_x, safe_line, attr)
                    else:
                        status_attr = status_colors.get(task.status, 0)
                        # Draw ID
                        if start_x + id_width < curses.COLS:
                            stdscr.addstr(y, start_x, f"{task.id:<{id_width}} ", attr)
                        # Draw status with color
                        status_x = start_x + id_width + 1
                        if status_x + status_width < curses.COLS:
                            stdscr.addstr(y, status_x, f"{task.status:<{status_width}}", status_attr | attr)
                        # Draw rest
                        rest = f" {pri:<{pri_width}} {task.milestone or '-':<{m_width}} {truncated_title}"
                        remaining_x = status_x + status_width
                        max_rest_width = min(list_width - (remaining_x - start_x), curses.COLS - remaining_x - 1)
                        if remaining_x < curses.COLS and max_rest_width > 0:
                            stdscr.addstr(y, remaining_x, rest[:max_rest_width], attr)
                except curses.error:
                    pass  # Ignore drawing errors
    
    def draw_task_details(self, stdscr, task: Optional[EnhancedTask], height: int, width: int, start_y: int, start_x: int):
        """Draw task details on the right side"""
        # Check boundaries
        max_x = curses.COLS - 1
        max_y = curses.LINES - 1
        
        if start_x >= max_x or width < 20:
            return
            
        if not task:
            try:
                if start_y + height // 2 < max_y:
                    stdscr.addstr(start_y + height // 2, min(start_x + 2, max_x - 30), "Select a task to view details")
            except curses.error:
                pass
            return
        
        # Use the available width but respect terminal boundaries
        detail_width = min(width - 2, max_x - start_x - 1)
        if detail_width < 20:
            return
            
        y = start_y
        
        # Helper function to safely add string
        def safe_addstr(y, x, text, *args):
            if y >= max_y or x >= max_x:
                return False
            try:
                safe_text = text[:min(len(text), max_x - x)]
                if args:
                    stdscr.addstr(y, x, safe_text, *args)
                else:
                    stdscr.addstr(y, x, safe_text)
                return True
            except curses.error:
                return False
        
        # Title
        if not safe_addstr(y, start_x, "Task Details", curses.A_BOLD | curses.color_pair(4)):
            return
        y += 1
        safe_addstr(y, start_x, "─" * min(detail_width, max_x - start_x))
        y += 2
        
        # Basic info
        safe_addstr(y, start_x, "ID: ", curses.A_BOLD)
        safe_addstr(y, start_x + 4, task.id)
        y += 1
        
        if y >= max_y - 2:
            return
            
        safe_addstr(y, start_x, "Title: ", curses.A_BOLD)
        # Use full width for title
        title_lines = self._wrap_text(task.title, detail_width - 7)
        for i, line in enumerate(title_lines[:2]):  # Limit title lines
            if y < max_y - 1:
                safe_addstr(y, start_x + 7, line)
                y += 1
        
        if y < max_y - 1:
            safe_addstr(y, start_x, "Status: ", curses.A_BOLD)
            status_colors = {
                'todo': curses.color_pair(1),
                'in_progress': curses.color_pair(3),
                'done': curses.color_pair(2),
                'blocked': curses.color_pair(1)
            }
            safe_addstr(y, start_x + 8, task.status, status_colors.get(task.status, 0))
            y += 1
        
        if y < max_y - 1:
            safe_addstr(y, start_x, "Priority: ", curses.A_BOLD)
            pri_colors = {
                'critical': curses.color_pair(1),
                'high': curses.color_pair(3),
                'medium': curses.color_pair(3),
                'low': curses.color_pair(2)
            }
            safe_addstr(y, start_x + 10, task.priority, pri_colors.get(task.priority, 0))
            y += 1
        
        if y < max_y - 1:
            safe_addstr(y, start_x, "Milestone: ", curses.A_BOLD)
            safe_addstr(y, start_x + 11, task.milestone or "None")
            y += 2
        
        # Description
        if task.description and y < max_y - 3:
            safe_addstr(y, start_x, "Description:", curses.A_BOLD)
            y += 1
            desc_lines = self._wrap_text(task.description, detail_width)
            for line in desc_lines[:3]:  # Limit lines to prevent overflow
                if y < max_y - 2:
                    safe_addstr(y, start_x, line)
                    y += 1
            y += 1
        
        # Details (extended info)
        if hasattr(task, 'details') and task.details and y < max_y - 3:
            safe_addstr(y, start_x, "Implementation:", curses.A_BOLD)
            y += 1
            detail_lines = self._wrap_text(task.details, detail_width)
            for line in detail_lines[:3]:  # Limit lines
                if y < max_y - 2:
                    safe_addstr(y, start_x, line)
                    y += 1
            y += 1
        
        # Links
        if hasattr(task, 'links') and task.links and y < max_y - 3:
            safe_addstr(y, start_x, "Documents:", curses.A_BOLD)
            y += 1
            for link in task.links[:3]:  # Limit links
                if y < max_y - 2:
                    link_text = f"• {link['name']}"
                    safe_addstr(y, start_x, link_text[:detail_width], curses.color_pair(4))
                    y += 1
        
        # Subtasks - removed for now to save space
    
    def _wrap_text(self, text: str, width: int) -> List[str]:
        """Wrap text to fit within width"""
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
    
    def draw_help(self, stdscr, height: int):
        """Draw help bar at bottom"""
        help_text = "↑↓:Navigate │ Enter:Edit │ n:New │ d:Delete │ Space:Toggle │ f:Filter │ v:View │ q:Quit"
        y = height - 1
        stdscr.addstr(y, 0, help_text[:curses.COLS-1], curses.color_pair(4))
    
    def draw_status_bar(self, stdscr):
        """Draw status bar at top"""
        total = len(self.tool.tasks)
        filtered = len(self.get_filtered_tasks())
        
        status = f"AppFlowy Studios Roadmap │ Tasks: {filtered}/{total}"
        
        # Add filter indicators
        filters = []
        if self.filter_status:
            filters.append(f"Status:{self.filter_status}")
        if self.filter_priority:
            filters.append(f"Priority:{self.filter_priority}")
        if self.filter_milestone:
            filters.append(f"Milestone:{self.filter_milestone}")
        
        if filters:
            status += f" │ Filters: {', '.join(filters)}"
        
        stdscr.addstr(0, 0, status[:curses.COLS-1], curses.A_BOLD | curses.color_pair(4))
    
    def run(self, stdscr):
        """Main TUI loop"""
        # Initialize colors
        curses.start_color()
        curses.init_pair(1, curses.COLOR_RED, curses.COLOR_BLACK)     # Red
        curses.init_pair(2, curses.COLOR_GREEN, curses.COLOR_BLACK)   # Green
        curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)  # Yellow
        curses.init_pair(4, curses.COLOR_CYAN, curses.COLOR_BLACK)    # Cyan
        curses.init_pair(5, curses.COLOR_MAGENTA, curses.COLOR_BLACK) # Magenta
        
        curses.curs_set(0)  # Hide cursor
        stdscr.clear()
        
        while True:
            height, width = stdscr.getmaxyx()
            tasks = self.get_filtered_tasks()
            
            # Clear screen
            stdscr.clear()
            
            # Draw status bar
            self.draw_status_bar(stdscr)
            
            # Draw separator line
            stdscr.addstr(1, 0, "═" * (width - 1))
            
            # Calculate areas
            content_height = height - 4  # Minus status, separator, and help
            
            if self.view_mode == 'split':
                # Split view - fixed sizes to prevent overlap
                # Minimum terminal width needed: 100 chars
                if width < 100:
                    # Too narrow for split, use list only
                    self.draw_task_list(stdscr, tasks, content_height, width, 2, 0, width)
                else:
                    # Use fixed split: 45 chars for list, rest for details
                    list_width = min(45, width // 2)
                    
                    # Draw task list on left
                    self.draw_task_list(stdscr, tasks, content_height, width, 2, 0, list_width)
                    
                    # Draw vertical separator
                    for y in range(2, min(height - 1, curses.LINES - 1)):
                        try:
                            if list_width < curses.COLS:
                                stdscr.addstr(y, list_width, "│")
                        except curses.error:
                            pass
                    
                    # Draw task details on right
                    selected_task = tasks[self.selected_index] if tasks and self.selected_index < len(tasks) else None
                    details_start_x = list_width + 2
                    details_width = width - list_width - 3
                    if details_start_x < curses.COLS - 20:  # Ensure there's room for details
                        self.draw_task_details(stdscr, selected_task, content_height, details_width, 2, details_start_x)
            else:
                # List view only
                self.draw_task_list(stdscr, tasks, content_height, width, 2, 0, width)
            
            # Draw help bar
            self.draw_help(stdscr, height)
            
            # Refresh screen
            stdscr.refresh()
            
            # Handle input
            key = stdscr.getch()
            
            if key == ord('q'):
                break
            elif key == curses.KEY_UP:
                if self.selected_index > 0:
                    self.selected_index -= 1
                    if self.selected_index < self.scroll_offset:
                        self.scroll_offset = self.selected_index
            elif key == curses.KEY_DOWN:
                if self.selected_index < len(tasks) - 1:
                    self.selected_index += 1
                    if self.selected_index >= self.scroll_offset + content_height - 2:
                        self.scroll_offset = self.selected_index - content_height + 3
            elif key == ord('v'):
                # Toggle view mode
                self.view_mode = 'list' if self.view_mode == 'split' else 'split'
            elif key == ord(' '):
                # Toggle task status
                if tasks and self.selected_index < len(tasks):
                    task = tasks[self.selected_index]
                    status_cycle = ['todo', 'in_progress', 'done', 'todo']
                    current_idx = status_cycle.index(task.status) if task.status in status_cycle else 0
                    task.status = status_cycle[current_idx + 1]
                    task.updated = datetime.now().isoformat()
                    self.tool.save_tasks()
            elif key == ord('f'):
                # Clear filters (simple implementation)
                self.filter_status = None
                self.filter_priority = None
                self.filter_milestone = None
                self.selected_index = 0
                self.scroll_offset = 0

def main():
    """Main entry point"""
    workspace_root = os.environ.get('WORKSPACE_ROOT', '/home/jb/workspace/projects/tools/appflowy-studios/docs')
    
    try:
        tui = EnhancedRoadmapTUI(workspace_root)
        curses.wrapper(tui.run)
    except KeyboardInterrupt:
        print("\n✨ Roadmap TUI closed")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()