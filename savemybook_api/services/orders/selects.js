const { userBrief, bookImageFields, categoryName, cabinetBrief, coverImage } = require('../../lib/selects');

const orderInclude = {
  order_items: {
    include: {
      books: {
        include: {
          book_images: { select: bookImageFields },
          book_categories: { select: categoryName }
        }
      }
    }
  },
  smart_cabinets: {
    select: { cabinet_id: true, cabinet_name: true, address: true, open_time: true, close_time: true }
  },
  cabinet_slots: { select: { slot_id: true, slot_number: true } },
  users_orders_buyer_idTousers: { select: userBrief },
  users_orders_seller_idTousers: { select: userBrief },
  transaction_disputes: { select: { dispute_id: true, status: true, result: true } }
};

const adminOrderInclude = {
  users_orders_buyer_idTousers: { select: userBrief },
  users_orders_seller_idTousers: { select: userBrief },
  smart_cabinets: { select: cabinetBrief },
  order_items: {
    include: {
      books: {
        select: {
          book_id: true,
          title: true,
          book_images: coverImage
        }
      }
    }
  }
};

module.exports = { orderInclude, adminOrderInclude };
