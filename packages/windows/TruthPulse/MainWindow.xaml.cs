using System;
using Microsoft.UI;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using TruthPulse.Models;
using TruthPulse.ViewModels;
using Windows.System;

namespace TruthPulse;

public sealed partial class MainWindow : Window
{
    private readonly SearchViewModel _viewModel;

    public MainWindow()
    {
        InitializeComponent();
        ExtendsContentIntoTitleBar = true;

        _viewModel = new SearchViewModel(DispatcherQueue);
        _viewModel.PropertyChanged += ViewModel_PropertyChanged;
        _viewModel.ResultsChanged += OnResultsChanged;

        if (AppWindow != null)
        {
            AppWindow.TitleBar.ExtendsContentIntoTitleBar = true;
            AppWindow.Resize(new Windows.Graphics.SizeInt32(520, 580));
        }
    }

    public void BringToFront()
    {
        Activate();
        SearchBox?.Focus(FocusState.Programmatic);
        _ = _viewModel.OnPopoverOpenAsync();
    }

    private void ViewModel_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            switch (e.PropertyName)
            {
                case nameof(SearchViewModel.LastSyncText):
                    SyncStatusText.Text = _viewModel.LastSyncText ?? "";
                    break;
                case nameof(SearchViewModel.ErrorMessage):
                    if (_viewModel.ErrorMessage != null)
                        SyncStatusText.Text = _viewModel.ErrorMessage;
                    break;
            }
        });
    }

    private void OnResultsChanged()
    {
        // Already on UI thread (dispatched by ViewModel)
        RebuildResultsList();
    }

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _viewModel.Query = SearchBox.Text;
        // Results will be rebuilt via the ResultsChanged event after debounce
    }

    private void SearchBox_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        switch (e.Key)
        {
            case VirtualKey.Down:
                _viewModel.MoveSelection(1);
                UpdateSelectionHighlight();
                e.Handled = true;
                break;
            case VirtualKey.Up:
                _viewModel.MoveSelection(-1);
                UpdateSelectionHighlight();
                e.Handled = true;
                break;
            case VirtualKey.Enter:
                _viewModel.OpenSelectedMarket();
                e.Handled = true;
                break;
            case VirtualKey.Escape:
                AppWindow?.Hide();
                e.Handled = true;
                break;
        }
    }

    private void WindowComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _viewModel.SelectedWindow = WindowComboBox.SelectedIndex switch
        {
            0 => TrendWindow.OneDay,
            1 => TrendWindow.SevenDays,
            2 => TrendWindow.ThirtyDays,
            _ => TrendWindow.SevenDays
        };
    }

    private void ResultsListView_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ResultsListView.SelectedIndex >= 0 && ResultsListView.SelectedIndex < _viewModel.Results.Count)
        {
            _viewModel.SelectedResult = _viewModel.Results[ResultsListView.SelectedIndex];
        }
    }

    private void ResultsListView_ItemClick(object sender, ItemClickEventArgs e)
    {
        _viewModel.OpenSelectedMarket();
    }

    private void RebuildResultsList()
    {
        ResultsListView.Items.Clear();

        foreach (var result in _viewModel.Results)
        {
            var panel = CreateResultPanel(result);
            ResultsListView.Items.Add(panel);
        }

        ResultCountText.Text = _viewModel.Results.Count > 0
            ? $"{_viewModel.Results.Count} results"
            : "";

        UpdateSelectionHighlight();
    }

    private void UpdateSelectionHighlight()
    {
        if (_viewModel.SelectedResult != null)
        {
            var idx = _viewModel.Results.IndexOf(_viewModel.SelectedResult);
            if (idx >= 0 && idx < ResultsListView.Items.Count)
                ResultsListView.SelectedIndex = idx;
        }
    }

    private static Grid CreateResultPanel(SearchResult result)
    {
        var market = result.Market;

        var grid = new Grid
        {
            Padding = new Thickness(12, 10, 12, 10),
            ColumnSpacing = 12
        };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        // Left: title + subtitle + volume
        var leftStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };

        var titleBlock = new TextBlock
        {
            Text = market.Title,
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            TextWrapping = TextWrapping.Wrap,
            MaxLines = 2,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Foreground = new SolidColorBrush(ColorHelper.FromArgb(255, 26, 26, 26))
        };
        leftStack.Children.Add(titleBlock);

        // Subtitle: show eventTitle if different from title
        var subtitleText = market.EventTitle != null && market.EventTitle != market.Title
            ? market.EventTitle
            : market.Subtitle;

        if (!string.IsNullOrEmpty(subtitleText))
        {
            var subtitleBlock = new TextBlock
            {
                Text = subtitleText,
                FontSize = 11,
                Foreground = new SolidColorBrush(ColorHelper.FromArgb(255, 128, 128, 128)),
                TextTrimming = TextTrimming.CharacterEllipsis,
                MaxLines = 1,
                Margin = new Thickness(0, 2, 0, 0)
            };
            leftStack.Children.Add(subtitleBlock);
        }

        if (market.VolumeSignal > 0)
        {
            var volumeText = market.VolumeSignal >= 1_000_000
                ? $"${market.VolumeSignal / 1_000_000:F1}M vol"
                : market.VolumeSignal >= 1_000
                    ? $"${market.VolumeSignal / 1_000:F0}K vol"
                    : $"${market.VolumeSignal:F0} vol";

            var volumeBlock = new TextBlock
            {
                Text = volumeText,
                FontSize = 10,
                Foreground = new SolidColorBrush(ColorHelper.FromArgb(255, 170, 170, 170)),
                Margin = new Thickness(0, 2, 0, 0)
            };
            leftStack.Children.Add(volumeBlock);
        }

        Grid.SetColumn(leftStack, 0);
        grid.Children.Add(leftStack);

        // Right: odds badge using Border (StackPanel doesn't have CornerRadius/Background)
        if (result.EmphasizedOdds.HasValue)
        {
            var badgeContent = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                VerticalAlignment = VerticalAlignment.Center
            };

            var oddsText = new TextBlock
            {
                Text = $"{result.EmphasizedOdds}%",
                FontSize = 14,
                FontWeight = FontWeights.Bold,
                Foreground = new SolidColorBrush(Colors.White)
            };
            badgeContent.Children.Add(oddsText);

            var labelText = new TextBlock
            {
                Text = $" {result.EmphasizedOutcomeLabel}",
                FontSize = 11,
                Foreground = new SolidColorBrush(ColorHelper.FromArgb(255, 220, 255, 240)),
                VerticalAlignment = VerticalAlignment.Center
            };
            badgeContent.Children.Add(labelText);

            var badge = new Border
            {
                Padding = new Thickness(8, 4, 8, 4),
                CornerRadius = new CornerRadius(8),
                Background = new SolidColorBrush(ColorHelper.FromArgb(255, 16, 185, 129)),
                VerticalAlignment = VerticalAlignment.Center,
                Child = badgeContent
            };

            Grid.SetColumn(badge, 1);
            grid.Children.Add(badge);
        }

        return grid;
    }
}
