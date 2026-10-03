import SwiftUI

struct SocialFeedView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: FeedFilter = .discover
    @State private var isComposing = false

    private enum FeedFilter: String, CaseIterable, Identifiable {
        case following = "关注"
        case discover = "发现"
        var id: String { rawValue }
    }

    private var visiblePosts: [FeedPost] {
        let followingIDs = Set(store.people.filter(\.isFollowing).map(\.id))
        return store.posts.filter { post in
            filter == .discover || post.authorID == store.profile.id || followingIDs.contains(post.authorID)
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Circle().fill(KaXTheme.accent).frame(width: 5, height: 5)
                            Text("示例空间 · 本机动态")
                                .font(.caption)
                                .foregroundStyle(KaXTheme.muted)
                        }
                        Picker("动态范围", selection: $filter) {
                            ForEach(FeedFilter.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("feedFilterPicker")
                    }

                    if visiblePosts.isEmpty {
                        EmptyStateView(
                            symbol: "person.2",
                            title: "这里还没有动态",
                            message: "去发现看看，关注感兴趣的人，或分享你的一次测量。"
                        )
                        .padding(.vertical, 30)
                    } else {
                        ForEach(visiblePosts) { post in
                            FeedPostCardView(post: post)
                        }
                    }

                    Text("示例人物用于体验。你的发布、点赞和评论保存在此设备。")
                        .font(.caption)
                        .foregroundStyle(KaXTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 12)
                }
                .padding(20)
                .pageWidth()
            }
            .background(KaXTheme.background)
            .navigationTitle("动态")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isComposing = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .medium))
                    }
                    .accessibilityLabel("发布动态")
                    .accessibilityIdentifier("composeButton")
                }
            }
            .sheet(isPresented: $isComposing) {
                ComposePostView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .accessibilityIdentifier("feedScreen")
        }
    }
}

struct FeedPostCardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let post: FeedPost
    var navigatesToComments = true
    var onCommentsTapped: (() -> Void)? = nil

    private var authorName: String {
        post.authorID == store.profile.id ? store.profile.name : post.authorName
    }

    private var authorHandle: String {
        post.authorID == store.profile.id ? store.profile.handle : post.handle
    }

    private var authorInitials: String {
        post.authorID == store.profile.id ? socialInitials(store.profile.name) : post.initials
    }

    var body: some View {
        RoundedPanel {
            VStack(alignment: .leading, spacing: 16) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        authorLink
                        HStack(spacing: 10) {
                            OriginBadge(origin: post.origin)
                            postDate
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        authorLink
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 5) {
                            OriginBadge(origin: post.origin)
                            postDate
                        }
                    }
                }

                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.body)
                        .foregroundStyle(KaXTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                if !post.metricTitle.isEmpty && !post.metricValue.isEmpty {
                    PostMetricCardView(post: post)
                }

                Group {
                    if dynamicTypeSize >= .xxxLarge {
                        VStack(alignment: .leading, spacing: 0) {
                            likeButton
                            commentControl
                            shareControl
                        }
                    } else {
                        HStack(spacing: 20) {
                            likeButton
                            commentControl
                            Spacer(minLength: 0)
                            shareControl
                        }
                    }
                }
                .font(.subheadline)
                .buttonStyle(.plain)
            }
        }
    }

    private var authorLink: some View {
        NavigationLink {
            SocialProfileView(personID: post.authorID)
        } label: {
            HStack(spacing: 10) {
                AvatarView(initials: authorInitials)
                VStack(alignment: .leading, spacing: 3) {
                    Text(authorName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KaXTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(socialHandle(authorHandle))
                        .font(.caption)
                        .foregroundStyle(KaXTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看\(authorName)的个人动态")
        .accessibilityIdentifier("postAuthor-\(post.id.uuidString)")
    }

    private var postDate: some View {
        Text(post.date, style: .relative)
            .font(.caption2)
            .foregroundStyle(KaXTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var likeButton: some View {
        Button {
            store.toggleLike(postID: post.id)
        } label: {
            Label("\(post.likes)", systemImage: post.isLiked ? "heart.fill" : "heart")
                .foregroundStyle(post.isLiked ? KaXTheme.accent : KaXTheme.muted)
                .frame(minHeight: 44)
        }
        .accessibilityLabel("\(post.isLiked ? "取消点赞" : "点赞")，\(post.likes)个赞")
        .accessibilityIdentifier("likeButton-\(post.id.uuidString)")
    }

    @ViewBuilder
    private var commentControl: some View {
        if navigatesToComments {
            NavigationLink {
                PostDetailView(postID: post.id)
            } label: {
                commentLabel
            }
            .accessibilityLabel("查看\(post.comments.count)条评论")
            .accessibilityIdentifier("commentButton-\(post.id.uuidString)")
        } else {
            Button {
                onCommentsTapped?()
            } label: {
                commentLabel
            }
            .accessibilityLabel("添加评论，已有\(post.comments.count)条")
            .accessibilityIdentifier("commentButton-\(post.id.uuidString)")
        }
    }

    private var shareControl: some View {
        ShareLink(item: shareText) {
            Label("分享", systemImage: "square.and.arrow.up")
                .labelStyle(.iconOnly)
                .foregroundStyle(KaXTheme.muted)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("分享动态")
        .accessibilityIdentifier("sharePost-\(post.id.uuidString)")
    }

    private var commentLabel: some View {
        Label("\(post.comments.count)", systemImage: "bubble.right")
            .foregroundStyle(KaXTheme.muted)
            .frame(minHeight: 44)
    }

    private var shareText: String {
        var lines = ["\(authorName) · kaX"]
        if !post.caption.isEmpty { lines.append(post.caption) }
        if !post.metricTitle.isEmpty && !post.metricValue.isEmpty {
            lines.append("\(post.metricTitle)：\(post.metricValue) \(post.metricUnit)")
        }
        if !post.tag.isEmpty { lines.append(post.tag) }
        lines.append("数据来源：\(post.origin.title)")
        return lines.joined(separator: "\n")
    }
}

private struct PostMetricCardView: View {
    let post: FeedPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(post.metricTitle)
                .font(.subheadline)
                .foregroundStyle(KaXTheme.muted)
            MetricValue(value: post.metricValue, unit: post.metricUnit)
                .foregroundStyle(KaXTheme.ink)
            if !post.tag.isEmpty {
                Text(post.tag)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(KaXTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KaXTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

func socialHandle(_ handle: String) -> String {
    handle.hasPrefix("@") ? handle : "@\(handle)"
}

func socialMetric(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
}

func socialInitials(_ name: String) -> String {
    let words = name.split(separator: " ")
    if words.count > 1 {
        return String(words.prefix(2).compactMap(\.first)).uppercased()
    }
    return String(name.prefix(2)).uppercased()
}
