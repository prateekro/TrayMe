using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using Newtonsoft.Json;
using TrayMe.Windows.Models;

namespace TrayMe.Windows.Managers
{
    public class NotesManager : INotifyPropertyChanged
    {
        private ObservableCollection<Note> _notes = new();
        private string _searchText = string.Empty;
        private Note? _selectedNote;

        public ObservableCollection<Note> Notes
        {
            get => _notes;
            set { _notes = value; OnPropertyChanged(); OnPropertyChanged(nameof(FilteredNotes)); }
        }

        public string SearchText
        {
            get => _searchText;
            set { _searchText = value; OnPropertyChanged(); OnPropertyChanged(nameof(FilteredNotes)); }
        }

        public Note? SelectedNote
        {
            get => _selectedNote;
            set { _selectedNote = value; OnPropertyChanged(); }
        }

        public ObservableCollection<Note> FilteredNotes
        {
            get
            {
                if (string.IsNullOrWhiteSpace(SearchText))
                    return Notes;
                    
                var filtered = Notes.Where(n => 
                    n.Title.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
                    n.Content.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
                return new ObservableCollection<Note>(filtered);
            }
        }

        public ObservableCollection<Note> PinnedNotes => 
            new ObservableCollection<Note>(Notes.Where(n => n.IsPinned));

        public ObservableCollection<Note> UnpinnedNotes => 
            new ObservableCollection<Note>(Notes.Where(n => !n.IsPinned));

        public NotesManager()
        {
            LoadFromDisk();

            // Create a default note if empty
            if (!Notes.Any())
            {
                CreateNote();
            }
        }

        public Note CreateNote()
        {
            var newNote = new Note("", "");
            Notes.Insert(0, newNote);
            SelectedNote = newNote;
            OnPropertyChanged(nameof(FilteredNotes));
            SaveToDisk();
            return newNote;
        }

        public void UpdateNote(Note note, string? title = null, string? content = null)
        {
            var existingNote = Notes.FirstOrDefault(n => n.Id == note.Id);
            if (existingNote == null) return;

            existingNote.Update(title, content);
            OnPropertyChanged(nameof(FilteredNotes));
            SaveToDisk();
        }

        public void DeleteNote(Note note)
        {
            Notes.Remove(note);

            if (SelectedNote?.Id == note.Id)
            {
                SelectedNote = Notes.FirstOrDefault();
            }

            OnPropertyChanged(nameof(FilteredNotes));
            SaveToDisk();
        }

        public void TogglePin(Note note)
        {
            var existingNote = Notes.FirstOrDefault(n => n.Id == note.Id);
            if (existingNote == null) return;

            existingNote.IsPinned = !existingNote.IsPinned;

            // Re-sort: pinned notes first, then by modified date
            var sorted = Notes.OrderByDescending(n => n.IsPinned)
                              .ThenByDescending(n => n.ModifiedDate)
                              .ToList();
            Notes.Clear();
            foreach (var n in sorted)
            {
                Notes.Add(n);
            }

            OnPropertyChanged(nameof(FilteredNotes));
            OnPropertyChanged(nameof(PinnedNotes));
            OnPropertyChanged(nameof(UnpinnedNotes));
            SaveToDisk();
        }

        // Persistence
        private string SavePath
        {
            get
            {
                var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                var folder = Path.Combine(appData, "TrayMe");
                Directory.CreateDirectory(folder);
                return Path.Combine(folder, "notes.json");
            }
        }

        public void SaveToDisk()
        {
            try
            {
                var json = JsonConvert.SerializeObject(Notes, Formatting.Indented, new JsonSerializerSettings
                {
                    DateFormatHandling = DateFormatHandling.IsoDateFormat
                });
                File.WriteAllText(SavePath, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to save notes: {ex.Message}");
            }
        }

        private void LoadFromDisk()
        {
            try
            {
                if (!File.Exists(SavePath))
                    return;

                var json = File.ReadAllText(SavePath);
                var notes = JsonConvert.DeserializeObject<ObservableCollection<Note>>(json);

                if (notes != null)
                {
                    Notes = notes;
                    SelectedNote = notes.FirstOrDefault();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to load notes: {ex.Message}");
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
