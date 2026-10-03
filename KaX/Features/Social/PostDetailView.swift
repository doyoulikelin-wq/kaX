import SwiftUI

struct PostDetailView: View {
    @Environment(AppStore.self) private var store
    let postID: UUID
    @State private var comment = ""
    @State private var showsSaveError = false
    @FocusState private var isCommentFocused: Bool

    private var post: FeedPost? { store.posts.first { $0.id == postID } }
    private var canSend: Bool { !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let post {
                        FeedPostCardView(post: post, navigatesToComments: false) {
                            isCommentFocused = true
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeading(title: "评论", trailing: "\(post.comments.count) 条")
                            if post.comments.isEmpty {
                                Text("还没有评论。聊聊你看到了什么。")
                                    .font(.subheadline)
                                    .foregroundStyle(KaXTheme.muted)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(post.comments) { item in
                                    commentRow(item)
                                        .id(item.id)
                                }
                            }
                            Text("评论保存在此设备。")
                                .font(.caption)
                                .foregroundStyle(KaXTheme.muted)
                        }
                        .padding(.horizontal, 4)
                        Color.clear.frame(height: 1).id("commentsBottom")
                    } else {
                        EmptyStateView(symbol: "bubble.left", title: "动态暂不可用", message: "回到动态页查看其他记录。")
                    }
                }
                .padding(20)
                .pageWidth()
            }
            .background(KaXTheme.background)
            .navigationTitle("动态详情")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if post != nil {
                    commentComposer {
                        sendComment()
                        if !showsSaveError {
                            withAnimation { proxy.scrollTo("commentsBottom", anchor: .bottom) }
                        }
                    }
                }
            }
            .alert("评论未能保存", isPresented: $showsSaveError) {
                Button("好", role: .cancel) { }
            } message: {
                Text(store.persistenceError ?? "请稍后重试。")
            }
        }
    }

    private func commentRow(_ item: PostComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(initials: socialInitials(item.authorName), size: 34)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.authorName).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(item.date, style: .relative).font(.caption2).foregroundStyle(KaXTheme.muted)
                }
                Text(item.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .background(KaXTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func commentComposer(send: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 12) {
                TextField("写一条评论", text: $comment, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(KaXTheme.background, in: RoundedRectangle(cornerRadius: 20))
                    .focused($isCommentFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .accessibilityLabel("评论内容")
                    .accessibilityIdentifier("commentField")
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(canSend ? KaXTheme.accent : KaXTheme.accent.opacity(0.3), in: Circle())
                }
                .disabled(!canSend)
                .accessibilityLabel("发送评论")
                .accessibilityIdentifier("sendCommentButton")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .pageWidth()
        }
        .background(KaXTheme.card)
    }

    private func sendComment() {
        guard canSend else { return }
        store.addComment(postID: postID, text: comment.trimmingCharacters(in: .whitespacesAndNewlines))
        if store.persistenceError == nil {
            comment = ""
            isCommentFocused = false
        } else {
            showsSaveError = true
        }
    }
}
