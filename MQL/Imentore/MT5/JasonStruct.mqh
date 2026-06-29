struct OrderStruct
{
    int type;
    int ticket_master;
    int ticket_slave;
    int trace_id;
    long slave_id;
    long magicnumber;
    long transaction_id;
    double price_open;
    double lot;
    double stop_loss;
    double take_profit;
    string state;
    string symbol;
    int deal_ticket;
    long seconds_ago;
    string comment;
    string open_at;
};

class JasonStruct
{
private:
    OrderStruct orders[];  // Dynamic array of OrderStruct

public:
    void AddOrder(OrderStruct &order)
    {
        ArrayResize(orders, ArraySize(orders) + 1);
        orders[ArraySize(orders) - 1] = order;
    }

    void Size(){
        ArraySize(orders);
    }

    OrderStruct GetOrder(int index)
    {
        if(index < ArraySize(orders))
        {
            return orders[index];
        }
        else
        {
            OrderStruct invalidOrder;
            // Set invalidOrder fields to indicate it's invalid
            return invalidOrder;
        }
    }

    // Add other methods as needed...
};

