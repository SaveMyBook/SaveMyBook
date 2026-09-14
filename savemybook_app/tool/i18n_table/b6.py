# -*- coding: utf-8 -*-
"""訂單結算與爭議裁決的金流提示。"""

T = {
    '買家付的款項會退回錢包；賣家若已收到貨款會先收回。': (
        "The buyer's payment goes back to their wallet. If the seller was already paid, that amount is taken back first.",
        '買い手の支払いはウォレットに返金されます。売り手に代金が支払い済みの場合は先に回収します。',
        '구매자의 결제 금액이 지갑으로 환불됩니다. 판매자에게 이미 대금이 지급됐다면 먼저 회수합니다.',
        '买家付的款项会退回钱包；卖家若已收到货款会先收回。',
    ),
    '訂單回到申訴前的狀態繼續交易；若先前已完成取貨，貨款會撥給賣家。': (
        'The order returns to where it was before the dispute. If it was already picked up, the seller is paid.',
        '注文は申し立て前の状態に戻り、取引を続けます。受け取り済みだった場合は売り手に代金を支払います。',
        '주문이 이의 제기 전 상태로 돌아가 거래를 계속합니다. 이미 수령했다면 판매자에게 대금을 지급합니다.',
        '订单回到申诉前的状态继续交易；若先前已完成取货，货款会拨给卖家。',
    ),
    '這筆訂單的款項已經退回買家，不能再改回進行中或已完成': (
        'This order was already refunded to the buyer and cannot go back to in progress or completed',
        'この注文は買い手に返金済みのため、進行中や完了には戻せません',
        '이 주문은 이미 구매자에게 환불되어 진행 중이나 완료로 되돌릴 수 없습니다',
        '这笔订单的款项已经退回买家，不能再改回进行中或已完成',
    ),
    '已完成的訂單只能改為「退款處理中」或「已退款」': (
        'A completed order can only be changed to "Refund in progress" or "Refunded"',
        '完了した注文は「返金処理中」か「返金済み」にしか変更できません',
        '완료된 주문은 "환불 처리 중" 또는 "환불 완료"로만 변경할 수 있습니다',
        '已完成的订单只能改为“退款处理中”或“已退款”',
    ),
    r'確認後會把 $amount 代幣撥給賣家，書籍標記為已售出。': (
        r'Confirming pays $p0 tokens to the seller and marks the books as sold.',
        r'確定すると売り手に $p0 トークンを支払い、本を売却済みにします。',
        r'확인하면 판매자에게 $p0 토큰을 지급하고 책을 판매 완료로 표시합니다.',
        r'确认后会把 $p0 代币拨给卖家，书籍标记为已售出。',
    ),
    r'確認後會向賣家收回 $amount 代幣並退還給買家。賣家餘額不足時會變成負數。': (
        r"Confirming takes $p0 tokens back from the seller and refunds the buyer. The seller's balance may go negative.",
        r'確定すると売り手から $p0 トークンを回収し、買い手に返金します。売り手の残高が不足する場合はマイナスになります。',
        r'확인하면 판매자에게서 $p0 토큰을 회수해 구매자에게 환불합니다. 판매자 잔액이 부족하면 마이너스가 됩니다.',
        r'确认后会向卖家收回 $p0 代币并退还给买家。卖家余额不足时会变成负数。',
    ),
    '若先前還沒退款，會補退給買家。': (
        'If the buyer has not been refunded yet, the refund is issued now.',
        'まだ返金されていない場合は、買い手に返金します。',
        '아직 환불되지 않았다면 구매자에게 환불합니다.',
        '若先前还没退款，会补退给买家。',
    ),
    r'確認後會把買家付的 $amount 代幣退回，保留中的書重新上架。': (
        r"Confirming refunds the buyer's $p0 tokens and puts reserved books back on sale.",
        r'確定すると買い手が支払った $p0 トークンを返金し、取り置き中の本を再出品します。',
        r'확인하면 구매자가 결제한 $p0 토큰을 환불하고 예약 중인 책을 다시 판매합니다.',
        r'确认后会把买家付的 $p0 代币退回，保留中的书重新上架。',
    ),
}
