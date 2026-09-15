const userBrief = { user_id: true, nickname: true, avatar_url: true };
const userName = { user_id: true, nickname: true };

const coverImage = { select: { image_url: true }, take: 1 };
const bookImageFields = { image_id: true, image_url: true, image_type: true };
const categoryName = { category_name: true };

const cabinetBrief = { cabinet_id: true, cabinet_name: true, address: true };
const cabinetLocation = {
  cabinet_id: true, cabinet_name: true, address: true, open_time: true, close_time: true, latitude: true, longitude: true
};

const bookCard = {
  users: { select: userBrief },
  book_images: { select: bookImageFields },
  book_categories: { select: categoryName }
};

const orderItemsWithCover = {
  include: { books: { select: { title: true, book_images: coverImage } } }
};

module.exports = {
  userBrief, userName, coverImage, bookImageFields, categoryName, cabinetBrief, cabinetLocation, bookCard, orderItemsWithCover
};
