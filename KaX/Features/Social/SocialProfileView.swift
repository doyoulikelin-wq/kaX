import SwiftUI

struct SocialProfileView: View {
    @Environment(AppStore.self) private var store
    let personID: String

    private var isCurrentUser: Bool { personID == store.profile.id }
    private var person: Person? { store.people.first { $0.id == personID } }
    private var name: String { isCurrentUser ? store.profile.name : (person?.name ?? "用户") }
    private var handle: String { isCurrentUser ? store.profile.handle : (person?.handle ?? "kax") }
    private var initials: String { isCurrentUser ? socialInitials(store.profile.name) : (person?.initials ?? socialInitials(name)) }
    private var bio: String { isCurrentUser ? store.profile.bio : (person?.bio ?? "") }
    private var posts: [FeedPost] {
        store.posts.filter { $0.authorID == personID }.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                RoundedPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 16) {
                            AvatarView(initials: initials, size: 66)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(name).font(.title2.weight(.semibold))
                                Text(socialHandle(handle)).font(.subheadline).foregroundStyle(KaXTheme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        if !bio.isEmpty {
                            Text(bio).font(.body).fixedSize(horizontal: false, vertical: true)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 20) {
                                postCount.fixedSize()
                                recordCount.fixedSize()
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                postCount
                                recordCount
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(KaXTheme.muted)
                        if let person, !isCurrentUser {
                            Button {
                                store.toggleFollow(personID: personID)
                            } label: {
                                Label(person.isFollowing ? "已关注" : "关注", systemImage: person.isFollowing ? "checkmark" : "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .foregroundStyle(person.isFollowing ? KaXTheme.ink : .white)
                                    .background(person.isFollowing ? KaXTheme.background : KaXTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(person.isFollowing ? "取消关注\(name)" : "关注\(name)")
                            .accessibilityIdentifier("followButton-\(personID)")
                        }
                    }
                }

                SectionHeading(title: isCurrentUser ? "我的动态" : "\(name)的动态")
                if posts.isEmpty {
                    EmptyStateView(symbol: "square.and.pencil", title: "还没有动态", message: "新的测量与发现会出现在这里。")
                } else {
                    ForEach(posts) { post in FeedPostCardView(post: post) }
                }
            }
            .padding(20)
            .pageWidth()
        }
        .background(KaXTheme.background)
        .navigationTitle("个人动态")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("socialProfile-\(personID)")
    }

    private var postCount: some View {
        Label("\(posts.count) 条动态", systemImage: "square.stack")
    }

    @ViewBuilder
    private var recordCount: some View {
        if isCurrentUser {
            Label("\(store.records.count) 次记录", systemImage: "chart.bar")
        } else {
            Text("示例好友")
        }
    }
}
