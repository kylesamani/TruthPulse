using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using TruthPulse.Models;
using TruthPulse.ViewModels;

namespace TruthPulse;

public partial class MainWindow : Window
{
    private readonly SearchViewModel _viewModel;
    public SearchViewModel ViewModel => _viewModel;

    public MainWindow() : this(null) { }

    public MainWindow(TruthPulse.Services.SearchService? searchService)
    {
        InitializeComponent();

        try
        {
            Icon = new BitmapImage(new Uri("pack://application:,,,/Assets/tray-icon.ico"));
        }
        catch { }

        _viewModel = searchService != null
            ? new SearchViewModel(searchService)
            : new SearchViewModel();
        _viewModel.PropertyChanged += ViewModel_PropertyChanged;
        _viewModel.ResultsChanged += OnResultsChanged;
        _viewModel.TrendCacheUpdated += OnTrendCacheUpdated;

        Loaded += async (_, _) =>
        {
            FocusSearch();
            await _viewModel.OnPopoverOpenAsync();
        };
    }

    public void FocusSearch()
    {
        SearchBox.Focus();
        Keyboard.Focus(SearchBox);
    }

    private void ViewModel_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        Dispatcher.Invoke(() =>
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
        Dispatcher.Invoke(RebuildResultsList);
    }

    private void OnTrendCacheUpdated()
    {
        Dispatcher.Invoke(RebuildResultsList);
    }

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _viewModel.Query = SearchBox.Text;
        SearchPlaceholder.Visibility = string.IsNullOrEmpty(SearchBox.Text)
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    private void SearchBox_KeyDown(object sender, KeyEventArgs e)
    {
        switch (e.Key)
        {
            case Key.Down:
                _viewModel.MoveSelection(1);
                UpdateSelectionHighlight();
                e.Handled = true;
                break;
            case Key.Up:
                _viewModel.MoveSelection(-1);
                UpdateSelectionHighlight();
                e.Handled = true;
                break;
            case Key.Enter:
                _viewModel.OpenSelectedMarket();
                e.Handled = true;
                break;
            case Key.Escape:
                Hide();
                e.Handled = true;
                break;
        }
    }

    private void WindowRadio_Click(object sender, RoutedEventArgs e)
    {
        if (_viewModel == null) return;
        if (sender is System.Windows.Controls.RadioButton rb)
        {
            _viewModel.SelectedWindow = rb.Name switch
            {
                "Window1D" => TrendWindow.OneDay,
                "Window7D" => TrendWindow.SevenDays,
                "Window30D" => TrendWindow.ThirtyDays,
                _ => TrendWindow.SevenDays
            };
        }
    }

    private void ResultsListBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ResultsListBox.SelectedIndex >= 0 && ResultsListBox.SelectedIndex < _viewModel.Results.Count)
        {
            _viewModel.SelectedResult = _viewModel.Results[ResultsListBox.SelectedIndex];
        }
    }

    private void ResultsListBox_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        _viewModel.OpenSelectedMarket();
    }

    private void RebuildResultsList()
    {
        ResultsListBox.Items.Clear();

        foreach (var result in _viewModel.Results)
        {
            var trend = _viewModel.GetCachedTrend(result);
            var panel = CreateResultPanel(result, trend);
            ResultsListBox.Items.Add(panel);
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
            if (idx >= 0 && idx < ResultsListBox.Items.Count)
            {
                ResultsListBox.SelectedIndex = idx;
                ResultsListBox.ScrollIntoView(ResultsListBox.Items[idx]);
            }
        }
    }

    private static Grid CreateResultPanel(SearchResult result, MarketTrend? trend)
    {
        var market = result.Market;

        var grid = new Grid { Margin = new Thickness(12, 10, 12, 10) };
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
            MaxHeight = 40,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Foreground = new SolidColorBrush(Color.FromRgb(26, 26, 26))
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
                Foreground = new SolidColorBrush(Color.FromRgb(128, 128, 128)),
                TextTrimming = TextTrimming.CharacterEllipsis,
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
                Foreground = new SolidColorBrush(Color.FromRgb(170, 170, 170)),
                Margin = new Thickness(0, 2, 0, 0)
            };
            leftStack.Children.Add(volumeBlock);
        }

        Grid.SetColumn(leftStack, 0);
        grid.Children.Add(leftStack);

        // Right: odds + sparkline stacked vertically
        var rightStack = new StackPanel
        {
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Right
        };

        // Odds badge
        if (result.EmphasizedOdds.HasValue)
        {
            var badgeContent = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                HorizontalAlignment = HorizontalAlignment.Right
            };

            var oddsText = new TextBlock
            {
                Text = $"{result.EmphasizedOdds}%",
                FontSize = 14,
                FontWeight = FontWeights.Bold,
                Foreground = Brushes.White
            };
            badgeContent.Children.Add(oddsText);

            var labelText = new TextBlock
            {
                Text = $" {result.EmphasizedOutcomeLabel}",
                FontSize = 11,
                Foreground = new SolidColorBrush(Color.FromRgb(220, 255, 240)),
                VerticalAlignment = VerticalAlignment.Center
            };
            badgeContent.Children.Add(labelText);

            var badge = new Border
            {
                Padding = new Thickness(8, 4, 8, 4),
                CornerRadius = new CornerRadius(8),
                Background = new SolidColorBrush(Color.FromRgb(16, 185, 129)),
                HorizontalAlignment = HorizontalAlignment.Right,
                Child = badgeContent
            };
            rightStack.Children.Add(badge);
        }

        // Sparkline
        var sparkline = CreateSparkline(trend, 80, 28);
        sparkline.Margin = new Thickness(0, 6, 0, 0);
        sparkline.HorizontalAlignment = HorizontalAlignment.Right;
        rightStack.Children.Add(sparkline);

        Grid.SetColumn(rightStack, 1);
        grid.Children.Add(rightStack);

        return grid;
    }

    private static Border CreateSparkline(MarketTrend? trend, double width, double height)
    {
        var container = new Border
        {
            Width = width,
            Height = height,
            CornerRadius = new CornerRadius(6),
            Background = new SolidColorBrush(Color.FromArgb(40, 16, 185, 129)),
            ClipToBounds = true
        };

        if (trend == null || trend.Points.Count < 2)
        {
            var noTrendText = new TextBlock
            {
                Text = "No trend",
                FontSize = 9,
                Foreground = new SolidColorBrush(Color.FromRgb(170, 170, 170)),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            container.Child = noTrendText;
            return container;
        }

        var canvas = new Canvas { Width = width, Height = height };

        // Y axis: fixed 0-100%
        var points = trend.Points;
        var pointCollection = new PointCollection();
        for (int i = 0; i < points.Count; i++)
        {
            var x = width * i / Math.Max(points.Count - 1, 1);
            var normalizedY = points[i].Value / 100.0; // 0-100 scale
            var y = height - (normalizedY * height);
            pointCollection.Add(new Point(x, Math.Clamp(y, 0, height)));
        }

        var lineColor = (trend.Delta ?? 0) >= 0
            ? Color.FromRgb(16, 185, 129)   // green
            : Color.FromRgb(220, 50, 50);   // red

        var polyline = new Polyline
        {
            Points = pointCollection,
            Stroke = new SolidColorBrush(lineColor),
            StrokeThickness = 2,
            StrokeLineJoin = PenLineJoin.Round,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round
        };

        canvas.Children.Add(polyline);
        container.Child = canvas;

        return container;
    }
}
